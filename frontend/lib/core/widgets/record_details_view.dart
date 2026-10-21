import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/routes/app_routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';
import '../../app/theme/app_radius.dart';
import '../../shared/providers/app_state_providers.dart';
import '../../shared/services/mock_database_service.dart';
import '../models/raw_material_model.dart';
import '../models/vendor_model.dart';
import '../models/purchase_model.dart';
import '../models/production_model.dart';
import '../models/customer_model.dart';
import '../models/dealer_model.dart';
import '../models/architect_model.dart';
import '../models/project_model.dart';
import '../models/sale_model.dart';
import '../models/payment_model.dart';
import '../models/commission_model.dart';
import '../../features/sales/widgets/sales_pdf_generator.dart';
import '../utils/formatters.dart';
import 'erp_button.dart';
import 'erp_data_table.dart';
import 'erp_status_badge.dart';
import '../../shared/widgets/share_document_dialog.dart';
import '../../shared/widgets/whatsapp_quick_chat_dialog.dart';

class RecordDetailsView extends ConsumerWidget {
  final ActiveRecordDetails details;

  const RecordDetailsView({
    super.key,
    required this.details,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseServiceProvider);
    final stack = ref.read(activeRecordDetailsStackProvider.notifier);

    Widget detailsWidget = const SizedBox();
    String title = '';
    String subtitle = '';

    switch (details.recordType) {
      case 'rawMaterial':
        final rm = db.rawMaterials.where((r) => r.id == details.recordId).firstOrNull ?? (db.rawMaterials.isNotEmpty ? db.rawMaterials.first : null);
        if (rm == null) return _buildNotFound(context, stack, 'Raw Material');
        title = 'Raw Material Details';
        subtitle = '${rm.name} (${rm.itemCode})';
        detailsWidget = _buildRawMaterialDetails(context, ref, rm, db);
        break;

      case 'vendor':
        final v = db.vendors.where((ven) => ven.id == details.recordId).firstOrNull ?? (db.vendors.isNotEmpty ? db.vendors.first : null);
        if (v == null) return _buildNotFound(context, stack, 'Vendor');
        title = 'Vendor Details';
        subtitle = v.name;
        detailsWidget = _buildVendorDetails(context, ref, v, db);
        break;

      case 'purchase':
        final p = db.purchases.where((pur) => pur.id == details.recordId).firstOrNull ?? (db.purchases.isNotEmpty ? db.purchases.first : null);
        if (p == null) return _buildNotFound(context, stack, 'Purchase Order');
        title = 'Purchase Order Details';
        subtitle = p.purchaseNumber;
        detailsWidget = _buildPurchaseDetails(context, ref, p, db);
        break;

      case 'production':
        final po = db.productionOrders.where((o) => o.id == details.recordId).firstOrNull ?? (db.productionOrders.isNotEmpty ? db.productionOrders.first : null);
        if (po == null) return _buildNotFound(context, stack, 'Production Order');
        title = 'Production Order Details';
        subtitle = po.productionNumber;
        detailsWidget = _buildProductionDetails(context, ref, po, db);
        break;

      case 'customer':
        final c = db.customers.where((cust) => cust.id == details.recordId).firstOrNull ?? (db.customers.isNotEmpty ? db.customers.first : null);
        if (c == null) return _buildNotFound(context, stack, 'Customer');
        title = 'Customer Profile';
        subtitle = c.name;
        detailsWidget = _buildCustomerDetails(context, ref, c, db);
        break;

      case 'dealer':
        final d = db.dealers.where((dlr) => dlr.id == details.recordId).firstOrNull ?? (db.dealers.isNotEmpty ? db.dealers.first : null);
        if (d == null) return _buildNotFound(context, stack, 'Dealer');
        title = 'Dealer Profile';
        subtitle = d.name;
        detailsWidget = _buildDealerDetails(context, ref, d, db);
        break;

      case 'architect':
        final a = db.architects.where((arc) => arc.id == details.recordId).firstOrNull ?? (db.architects.isNotEmpty ? db.architects.first : null);
        if (a == null) return _buildNotFound(context, stack, 'Architect');
        title = 'Architect Profile';
        subtitle = a.name;
        detailsWidget = _buildArchitectDetails(context, ref, a, db);
        break;

      case 'project':
        final prj = db.projects.where((p) => p.id == details.recordId).firstOrNull ?? (db.projects.isNotEmpty ? db.projects.first : null);
        if (prj == null) return _buildNotFound(context, stack, 'Project');
        title = 'Project Details';
        subtitle = prj.name;
        detailsWidget = _buildProjectDetails(context, ref, prj, db);
        break;

      case 'quotation':
      case 'proformaInvoice':
      case 'salesOrder':
      case 'delivery':
      case 'invoice':
      case 'salesReturn':
        final s = db.sales.where((sale) => sale.id == details.recordId).firstOrNull ?? (db.sales.isNotEmpty ? db.sales.first : null);
        if (s == null) return _buildNotFound(context, stack, 'Sales Record');
        if (s.documentType == SalesDocumentType.quotation) {
          title = 'Quotation Details';
        } else if (s.documentType == SalesDocumentType.proformaInvoice) {
          title = 'Proforma Invoice Details';
        } else if (s.documentType == SalesDocumentType.salesOrder) {
          title = 'Sales Order Details';
        } else if (s.documentType == SalesDocumentType.delivery) {
          title = 'Delivery Challan Details';
        } else if (s.documentType == SalesDocumentType.salesReturn) {
          title = 'Sales Return & Credit Note Details';
        } else {
          title = 'Sales Tax Invoice Details';
        }
        subtitle = s.invoiceNumber;
        if (s.documentType == SalesDocumentType.salesReturn) {
          detailsWidget = _buildSalesReturnDetails(context, ref, s, db);
        } else {
          detailsWidget = _buildSaleDetails(context, ref, s, db);
        }
        break;

      case 'payment':
        final pay = db.payments.where((py) => py.id == details.recordId).firstOrNull ?? (db.payments.isNotEmpty ? db.payments.first : null);
        if (pay == null) return _buildNotFound(context, stack, 'Payment Record');
        title = 'Payment Voucher Details';
        subtitle = pay.paymentNumber;
        detailsWidget = _buildPaymentDetails(context, ref, pay, db);
        break;
    }

    return SingleChildScrollView(
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => stack.pop(),
                tooltip: 'Go Back',
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  subtitle,
                  style: AppTextStyles.subtitle.copyWith(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          detailsWidget,
        ],
      ),
    );
  }


  // -----------------------------------------------------------------
  // 1. Raw Material Details
  // -----------------------------------------------------------------
  Widget _buildRawMaterialDetails(BuildContext context, WidgetRef ref, RawMaterial rm, MockDatabaseService db) {
    final movements = db.stockMovements.where((m) => m.itemId == rm.id).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadius.lgBorderRadius,
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Material Info', style: AppTextStyles.h3),
                    const Divider(height: 24),
                    _buildInfoRow('Material Name', rm.name),
                    _buildInfoRow('Item SKU / Code', rm.itemCode),
                    _buildInfoRow('Category', rm.categoryName),
                    _buildInfoRow('Measurement Unit', rm.unit),
                    _buildInfoRow('Default Purchase Price', Formatters.formatCurrency(rm.defaultPurchasePrice)),
                    _buildInfoRow('GST Rate', '${rm.gstPercent}%'),
                    const SizedBox(height: 10),
                    Text('Preferred Vendor(s):', style: AppTextStyles.bodyBold),
                    const SizedBox(height: 8),
                    if (rm.preferredVendorIds.isEmpty)
                      Text('No preferred vendor linked.', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted))
                    else
                      Wrap(
                        spacing: 8,
                        children: List.generate(rm.preferredVendorIds.length, (idx) {
                          final vId = rm.preferredVendorIds[idx];
                          final vName = rm.preferredVendorNames[idx];
                          return ActionChip(
                            label: Text(vName, style: const TextStyle(color: Colors.white, fontSize: 12)),
                            backgroundColor: AppColors.primary,
                            onPressed: () {
                              ref.read(activeRecordDetailsStackProvider.notifier).push(vId, 'vendor', details.parentSection);
                            },
                          );
                        }),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadius.lgBorderRadius,
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Stock Summary', style: AppTextStyles.h3),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Current Stock:', style: AppTextStyles.bodyMedium),
                        Text(
                          '${Formatters.formatNumber(rm.currentStock)} ${rm.unit}',
                          style: AppTextStyles.h2.copyWith(color: rm.isLowStock ? AppColors.dangerText : AppColors.successText),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow('Minimum Stock Level', '${rm.minimumStock} ${rm.unit}'),
                    _buildInfoRow('Reorder Threshold', '${rm.reorderLevel} ${rm.unit}'),
                    _buildInfoRow('Total valuation', Formatters.formatCurrency(rm.totalValuation)),
                    const SizedBox(height: 16),
                    rm.isLowStock
                        ? ErpStatusBadge.danger('REORDER REQUIRED (LOW STOCK)')
                        : ErpStatusBadge.success('STOCK HEALTHY'),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text('Stock Movement History (Ledger)', style: AppTextStyles.h2),
        const SizedBox(height: 12),
        ErpDataTable(
          columns: const [
            ErpColumn(title: 'Date/Time'),
            ErpColumn(title: 'Activity Type'),
            ErpColumn(title: 'Reference Doc'),
            ErpColumn(title: 'IN Qty', isNumeric: true),
            ErpColumn(title: 'OUT Qty', isNumeric: true),
            ErpColumn(title: 'Ending Stock Balance', isNumeric: true),
            ErpColumn(title: 'Notes'),
          ],
          rows: movements.map((m) {
            return [
              Text(Formatters.formatDateTime(m.date), style: AppTextStyles.bodySmall),
              Text(m.transactionType.toString().split('.').last.toUpperCase(), style: AppTextStyles.bodyBold.copyWith(fontSize: 11)),
              Text(m.referenceNumber, style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary)),
              Text(m.stockIn > 0 ? '+${m.stockIn}' : '-', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.successText)),
              Text(m.stockOut > 0 ? '-${m.stockOut}' : '-', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.dangerText)),
              Text('${m.currentBalance} ${m.unit}', style: AppTextStyles.bodyBold),
              Text(m.notes ?? '-', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
            ];
          }).toList(),
        ),
      ],
    );
  }

  // -----------------------------------------------------------------
  // 2. Vendor Details
  // -----------------------------------------------------------------
  Widget _buildVendorDetails(BuildContext context, WidgetRef ref, Vendor v, MockDatabaseService db) {
    final vendorPurchases = db.purchases.where((p) => p.vendorId == v.id).toList();
    final sortedPurchases = List<Purchase>.from(vendorPurchases)..sort((a, b) => b.purchaseDate.compareTo(a.purchaseDate));
    final totalPurchased = vendorPurchases.fold(0.0, (sum, p) => sum + p.totalAmount);
    final totalPaid = vendorPurchases.fold(0.0, (sum, p) => sum + p.paidAmount);
    final totalPending = vendorPurchases.fold(0.0, (sum, p) => sum + p.pendingAmount);
    final vendorPayments = db.payments.where((p) => p.partyId == v.id || p.partyName.toLowerCase() == v.name.toLowerCase()).toList();

    // Catalog of materials supplied by this vendor
    final suppliedMaterials = <String, Map<String, dynamic>>{};
    for (final p in vendorPurchases) {
      for (final it in p.items) {
        final matKey = it.rawMaterialId ?? it.finishedProductId ?? it.rawMaterialCode ?? it.rawMaterialName ?? 'item';
        final matName = it.rawMaterialName ?? it.finishedProductName ?? 'Item';
        final matCode = it.rawMaterialCode ?? it.finishedProductCode ?? '-';
        if (!suppliedMaterials.containsKey(matKey)) {
          suppliedMaterials[matKey] = {
            'name': matName,
            'code': matCode,
            'unit': it.unit,
            'itemType': it.itemType.name.toUpperCase(),
            'totalQty': 0.0,
            'totalVal': 0.0,
            'lastRate': it.rate,
          };
        }
        suppliedMaterials[matKey]!['totalQty'] =
            (suppliedMaterials[matKey]!['totalQty'] as double) + it.quantity;
        suppliedMaterials[matKey]!['totalVal'] =
            (suppliedMaterials[matKey]!['totalVal'] as double) + it.lineTotal;
        suppliedMaterials[matKey]!['lastRate'] = it.rate;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadius.lgBorderRadius,
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Vendor Profile', style: AppTextStyles.h3),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chat, color: Colors.green, size: 20),
                              tooltip: 'Quick WhatsApp Message',
                              onPressed: () => WhatsAppQuickChatDialog.showCustomerQuickChat(
                                context,
                                customerName: v.name,
                                customerPhone: v.mobile,
                              ),
                            ),
                            const SizedBox(width: 8),
                            v.isDeleted
                                ? ErpStatusBadge.danger('DELETED / ARCHIVED')
                                : ErpStatusBadge.neutral('ACTIVE VENDOR'),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    if (v.isDeleted) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.08),
                          borderRadius: AppRadius.smBorderRadius,
                          border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Vendor Account is Soft-Deleted',
                                    style: AppTextStyles.bodyBold.copyWith(color: AppColors.dangerText),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Reason for Deletion: ${v.deleteReason != null && v.deleteReason!.trim().isNotEmpty ? v.deleteReason! : "Reason not specified"}',
                                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.dangerText),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    _buildInfoRow('Vendor Code', v.id),
                    _buildInfoRow('Company Name', v.name),
                    _buildInfoRow('Contact Person', v.contactPerson),
                    _buildInfoRow('Mobile / Phone', v.mobile),
                    _buildInfoRow('Email Address', v.email.isNotEmpty ? v.email : '-'),
                    _buildInfoRow('GST Registration', v.gstNumber.isNotEmpty ? v.gstNumber : '-'),
                    _buildInfoRow('PAN Number', v.panNumber.isNotEmpty ? v.panNumber : '-'),
                    _buildInfoRow('Factory / Address', v.address.isNotEmpty ? v.address : '-'),
                    _buildInfoRow('State', v.state.isNotEmpty ? v.state : '-'),
                    _buildInfoRow('PIN Code', v.pincode.isNotEmpty ? v.pincode : '-'),
                    _buildInfoRow('Account Created Date', Formatters.formatDate(v.createdAt)),
                    if (v.isDeleted)
                      _buildInfoRow(
                        'Deletion Reason',
                        v.deleteReason != null && v.deleteReason!.trim().isNotEmpty ? v.deleteReason! : 'Reason not specified',
                        valueColor: AppColors.dangerText,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadius.lgBorderRadius,
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Financial & Procurement Ledger', style: AppTextStyles.h3),
                    const Divider(height: 24),
                    _buildInfoRow('Total Purchases Invoiced', Formatters.formatCurrency(totalPurchased)),
                    _buildInfoRow('Total Amount Disbursed', Formatters.formatCurrency(totalPaid)),
                    _buildInfoRow('Pending Dues on Orders', Formatters.formatCurrency(totalPending)),
                    _buildInfoRow('Credit Limit Allowed', Formatters.formatCurrency(v.creditLimit)),
                    _buildInfoRow('Payment Terms', v.paymentTerms),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Outstanding Payables Due:', style: AppTextStyles.bodyBold),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            Formatters.formatCurrency(v.outstandingBalance),
                            textAlign: TextAlign.end,
                            style: AppTextStyles.h2.copyWith(color: v.outstandingBalance > 0 ? AppColors.dangerText : AppColors.successText),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: v.outstandingBalance > 0 ? Colors.red.withValues(alpha: 0.08) : Colors.green.withValues(alpha: 0.08),
                        borderRadius: AppRadius.smBorderRadius,
                        border: Border.all(color: v.outstandingBalance > 0 ? Colors.red.withValues(alpha: 0.3) : Colors.green.withValues(alpha: 0.3)),
                      ),
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text('Payable Status:', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                          Text(
                            v.outstandingBalance > 0 ? 'PAYMENT OUTSTANDING' : 'ALL DUES CLEARED',
                            style: AppTextStyles.bodyBold.copyWith(color: v.outstandingBalance > 0 ? AppColors.dangerText : AppColors.successText),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text('Purchase Orders History', style: AppTextStyles.h2),
        const SizedBox(height: 12),
        if (sortedPurchases.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: AppRadius.mdBorderRadius, border: Border.all(color: AppColors.border)),
            child: Text('No purchase orders recorded for this vendor yet.', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
          )
        else
          ErpDataTable(
            columns: const [
              ErpColumn(title: 'PO Number'),
              ErpColumn(title: 'Purchase Date'),
              ErpColumn(title: 'Vendor Invoice'),
              ErpColumn(title: 'Items Count', isNumeric: true),
              ErpColumn(title: 'Total Amount', isNumeric: true),
              ErpColumn(title: 'Paid Amount', isNumeric: true),
              ErpColumn(title: 'Pending Due', isNumeric: true),
              ErpColumn(title: 'Status'),
            ],
            rows: sortedPurchases.map((p) {
              return [
                InkWell(
                  onTap: () => ref.read(activeRecordDetailsStackProvider.notifier).push(p.id, 'purchase', details.parentSection),
                  child: Text(p.purchaseNumber, style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary, decoration: TextDecoration.underline)),
                ),
                Text(Formatters.formatDate(p.purchaseDate), style: AppTextStyles.bodySmall),
                Text(p.vendorInvoiceNumber.isNotEmpty ? p.vendorInvoiceNumber : '-', style: AppTextStyles.bodySmall),
                Text('${p.items.length} items', style: AppTextStyles.bodySmall),
                Text(Formatters.formatCurrency(p.totalAmount), style: AppTextStyles.bodyBold),
                Text(Formatters.formatCurrency(p.paidAmount), style: AppTextStyles.bodySmall.copyWith(color: AppColors.successText)),
                Text(
                  Formatters.formatCurrency(p.pendingAmount),
                  style: AppTextStyles.bodyBold.copyWith(color: p.pendingAmount > 0 ? AppColors.dangerText : AppColors.textMuted),
                ),
                ErpStatusBadge.neutral(p.statusLabel.toUpperCase()),
              ];
            }).toList(),
          ),

        if (vendorPayments.isNotEmpty) ...[
          const SizedBox(height: 28),
          Text('Payment Transactions & Disbursements', style: AppTextStyles.h2),
          const SizedBox(height: 12),
          ErpDataTable(
            columns: const [
              ErpColumn(title: 'Payment No'),
              ErpColumn(title: 'Payment Date'),
              ErpColumn(title: 'Reference / UTR'),
              ErpColumn(title: 'PO Reference'),
              ErpColumn(title: 'Amount (₹)', isNumeric: true),
              ErpColumn(title: 'Payment Mode'),
              ErpColumn(title: 'Status'),
            ],
            rows: vendorPayments.map((pay) {
              return [
                Text(pay.paymentNumber, style: AppTextStyles.bodyBold),
                Text(Formatters.formatDate(pay.paymentDate), style: AppTextStyles.bodySmall),
                Text(pay.transactionReference ?? '-', style: AppTextStyles.bodySmall),
                Text(pay.referenceDocumentNumber ?? '-', style: AppTextStyles.bodySmall),
                Text(Formatters.formatCurrency(pay.amount), style: AppTextStyles.bodyBold.copyWith(color: AppColors.successText)),
                Text(pay.paymentMode.name.toUpperCase(), style: AppTextStyles.bodySmall),
                ErpStatusBadge.success('DISBURSED'),
              ];
            }).toList(),
          ),
        ],

        if (suppliedMaterials.isNotEmpty) ...[
          const SizedBox(height: 28),
          Text('Supplied Raw Materials & Products Catalog', style: AppTextStyles.h2),
          const SizedBox(height: 12),
          ErpDataTable(
            columns: const [
              ErpColumn(title: 'Item Code'),
              ErpColumn(title: 'Material Name'),
              ErpColumn(title: 'Category / Type'),
              ErpColumn(title: 'Cumulative Quantity Supplied'),
              ErpColumn(title: 'Last Procurement Rate (₹)', isNumeric: true),
              ErpColumn(title: 'Total Procurement Valuation (₹)', isNumeric: true),
            ],
            rows: suppliedMaterials.values.map((mat) {
              return [
                Text(mat['code'] as String, style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary)),
                Text(mat['name'] as String, style: AppTextStyles.bodyMedium),
                Text(mat['itemType'] as String, style: AppTextStyles.bodySmall),
                Text('${Formatters.formatNumber(mat['totalQty'] as double)} ${mat['unit']}', style: AppTextStyles.bodyMedium),
                Text(Formatters.formatCurrency(mat['lastRate'] as double), style: AppTextStyles.bodySmall),
                Text(Formatters.formatCurrency(mat['totalVal'] as double), style: AppTextStyles.bodyBold),
              ];
            }).toList(),
          ),
        ],
      ],
    );
  }

  // -----------------------------------------------------------------
  // 3. Purchase Details
  // -----------------------------------------------------------------
  Widget _buildPurchaseDetails(BuildContext context, WidgetRef ref, Purchase p, MockDatabaseService db) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadius.lgBorderRadius,
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PO Header info', style: AppTextStyles.h3),
                    const Divider(height: 24),
                    _buildInfoRow('Purchase Order No', p.purchaseNumber),
                    _buildInfoRow('PO Created Date', Formatters.formatDate(p.purchaseDate)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Vendor Company:', style: AppTextStyles.bodyMedium),
                        InkWell(
                          onTap: () => ref.read(activeRecordDetailsStackProvider.notifier).push(p.vendorId, 'vendor', details.parentSection),
                          child: Text(p.vendorName, style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary, decoration: TextDecoration.underline)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow('Vendor Invoice Number', p.vendorInvoiceNumber),
                    _buildInfoRow('Vendor Invoice Date', Formatters.formatDate(p.invoiceDate)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadius.lgBorderRadius,
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Payment Summary', style: AppTextStyles.h3),
                    const Divider(height: 24),
                    _buildInfoRow('Grand Total Amount', Formatters.formatCurrency(p.totalAmount)),
                    if (p.transportationCharges > 0)
                      _buildInfoRow('Transportation / Freight', Formatters.formatCurrency(p.transportationCharges)),
                    _buildInfoRow('Amount Paid to Date', Formatters.formatCurrency(p.paidAmount)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Outstanding Balance:', style: AppTextStyles.bodyBold),
                        Text(
                          Formatters.formatCurrency(p.pendingAmount),
                          style: AppTextStyles.bodyBold.copyWith(color: p.pendingAmount > 0 ? AppColors.dangerText : AppColors.successText, fontSize: 16),
                        ),
                      ],
                    ),
                    _buildInfoRow('Preferred Payment Mode', p.paymentMode.toString().split('.').last.toUpperCase()),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Order Status:', style: AppTextStyles.bodyBold),
                        Text(p.statusLabel, style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text('Purchase Line Items', style: AppTextStyles.h2),
        const SizedBox(height: 12),
        ErpDataTable(
          columns: const [
            ErpColumn(title: 'Item Code'),
            ErpColumn(title: 'Material Name'),
            ErpColumn(title: 'Purchase Qty'),
            ErpColumn(title: 'Rate per Unit', isNumeric: true),
            ErpColumn(title: 'Landed Rate', isNumeric: true),
            ErpColumn(title: 'Discount Amount', isNumeric: true),
            ErpColumn(title: 'GST Tax', isNumeric: true),
            ErpColumn(title: 'Line Total', isNumeric: true),
          ],
          rows: p.items.map((item) {
            return [
              InkWell(
                onTap: () {
                  final targetType = item.itemType == PurchaseItemType.finishedProduct ? 'finishedProduct' : 'rawMaterial';
                  ref.read(activeRecordDetailsStackProvider.notifier).push(item.itemId, targetType, details.parentSection);
                },
                child: Text(item.displayCode, style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary)),
              ),
              Text(item.displayName, style: AppTextStyles.bodyMedium),
              Text('${item.quantity} ${item.unit}', style: AppTextStyles.bodyMedium),
              Text(Formatters.formatCurrency(item.rate), style: AppTextStyles.bodySmall),
              Text(
                item.landedRate > 0 ? Formatters.formatCurrency(item.landedRate) : Formatters.formatCurrency(item.rate),
                style: AppTextStyles.bodySmall.copyWith(
                  color: item.landedRate > item.rate ? AppColors.successText : AppColors.textPrimary,
                  fontWeight: item.landedRate > item.rate ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              Text(Formatters.formatCurrency(item.discountAmount), style: AppTextStyles.bodySmall),
              Text('${item.gstPercent}%', style: AppTextStyles.bodySmall),
              Text(Formatters.formatCurrency(item.lineTotal), style: AppTextStyles.bodyBold),
            ];
          }).toList(),
        ),
      ],
    );
  }

  // -----------------------------------------------------------------
  // 4. Production Details
  // -----------------------------------------------------------------
  Widget _buildProductionDetails(BuildContext context, WidgetRef ref, ProductionOrder po, MockDatabaseService db) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadius.lgBorderRadius,
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Batch Production Header', style: AppTextStyles.h3),
                    const Divider(height: 24),
                    _buildInfoRow('Production Run No', po.productionNumber),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Finished Product Output:', style: AppTextStyles.bodyMedium),
                        InkWell(
                          onTap: () => ref.read(activeRecordDetailsStackProvider.notifier).push(po.finishedProductId, 'finishedProduct', details.parentSection),
                          child: Text(po.finishedProductName, style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary, decoration: TextDecoration.underline)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow('Finished Code', po.finishedProductCode),
                    _buildInfoRow('Planned Quantity', '${po.plannedQuantity} ${po.unit}'),
                    _buildInfoRow('Actual Produced Qty', '${po.actualQuantityProduced} ${po.unit}'),
                    _buildInfoRow('Production Run Date', Formatters.formatDate(po.productionDate)),
                    _buildInfoRow('Remarks / QC Notes', po.notes ?? '-'),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadius.lgBorderRadius,
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Batch Cost Breakdown', style: AppTextStyles.h3),
                    const Divider(height: 24),
                    _buildInfoRow('Raw Material Valuation', Formatters.formatCurrency(po.rawMaterialCost)),
                    _buildInfoRow('Labour Overheads', Formatters.formatCurrency(po.labourCost)),
                    _buildInfoRow('Other Operational Costs', Formatters.formatCurrency(po.otherExpenses)),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Batch Cost:', style: AppTextStyles.bodyBold),
                        Text(Formatters.formatCurrency(po.totalProductionCost), style: AppTextStyles.h2.copyWith(color: AppColors.primary)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: AppRadius.smBorderRadius,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Calculated Unit Cost:', style: AppTextStyles.bodyBold.copyWith(color: AppColors.primaryDark)),
                          Text(Formatters.formatCurrency(po.costPerUnit), style: AppTextStyles.bodyBold.copyWith(color: AppColors.primaryDark, fontSize: 16)),
                        ],
                      ),
                    ),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Current Status:', style: AppTextStyles.bodyBold),
                        Text(po.statusLabel.toUpperCase(), style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text('Raw Materials Consumed', style: AppTextStyles.h2),
        const SizedBox(height: 12),
        ErpDataTable(
          columns: const [
            ErpColumn(title: 'Material SKU'),
            ErpColumn(title: 'Material Name'),
            ErpColumn(title: 'Quantity Consumed'),
            ErpColumn(title: 'Standard Cost Rate', isNumeric: true),
            ErpColumn(title: 'Subtotal Valuation', isNumeric: true),
          ],
          rows: po.rawMaterialsUsed.map((rm) {
            return [
              InkWell(
                onTap: () => ref.read(activeRecordDetailsStackProvider.notifier).push(rm.rawMaterialId, 'rawMaterial', details.parentSection),
                child: Text(rm.rawMaterialCode, style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary)),
              ),
              Text(rm.rawMaterialName, style: AppTextStyles.bodyMedium),
              Text('${rm.quantityUsed} ${rm.unit}', style: AppTextStyles.bodyMedium),
              Text(Formatters.formatCurrency(rm.unitCost), style: AppTextStyles.bodySmall),
              Text(Formatters.formatCurrency(rm.totalCost), style: AppTextStyles.bodyBold),
            ];
          }).toList(),
        ),
      ],
    );
  }

  // -----------------------------------------------------------------
  // 5. Customer Details
  // -----------------------------------------------------------------
  Widget _buildCustomerDetails(BuildContext context, WidgetRef ref, Customer c, MockDatabaseService db) {
    final customerSales = db.sales.where((s) => s.partyId == c.id && s.documentType != SalesDocumentType.salesReturn).toList();
    final customerReturns = db.salesReturns.where((r) => r.partyId == c.id).toList();
    final grossInvoiced = customerSales.where((s) => s.documentType == SalesDocumentType.invoice).fold(0.0, (sum, s) => sum + s.totalAmount);
    final approvedReturns = customerReturns.where((r) => r.salesReturnStatus == SalesReturnStatus.approved).fold(0.0, (sum, r) => sum + r.totalAmount);
    final netSalesRevenue = (grossInvoiced - approvedReturns).clamp(0.0, double.infinity);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadius.lgBorderRadius,
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Customer Profile', style: AppTextStyles.h3),
                        IconButton(
                          icon: const Icon(Icons.chat, color: Colors.green, size: 20),
                          tooltip: 'Quick WhatsApp Message',
                          onPressed: () => WhatsAppQuickChatDialog.showCustomerQuickChat(
                            context,
                            customerName: c.name,
                            customerPhone: c.mobile,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    _buildInfoRow('Customer Code', c.id),
                    _buildInfoRow('Client Name', c.name),
                    if (c.isAlsoArchitect || c.linkedArchitectId != null) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Dual Entity Role:', style: AppTextStyles.bodyMedium),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: Colors.purple.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
                            child: const Text('ARCHITECT-CUSTOMER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.purple)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    _buildInfoRow('Contact Number', c.mobile),
                    _buildInfoRow('Email Address', c.email),
                    _buildInfoRow('Registered Address', c.address),
                    _buildInfoRow('State', c.state.isNotEmpty ? c.state : '-'),
                    _buildInfoRow('PIN Code', c.pincode.isNotEmpty ? c.pincode : '-'),
                    _buildInfoRow('Account Created Date', Formatters.formatDate(c.createdAt)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadius.lgBorderRadius,
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Financial & Credit Ledger', style: AppTextStyles.h3),
                    const Divider(height: 24),
                    _buildInfoRow('Gross Sales Invoiced', Formatters.formatCurrency(grossInvoiced)),
                    _buildInfoRow('Approved Sales Returns', Formatters.formatCurrency(approvedReturns)),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Net Sales Revenue:', style: AppTextStyles.bodyBold),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(Formatters.formatCurrency(netSalesRevenue), textAlign: TextAlign.end, style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Receivables Due:', style: AppTextStyles.bodyMedium),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            Formatters.formatCurrency(c.outstandingAmount),
                            textAlign: TextAlign.end,
                            style: AppTextStyles.h2.copyWith(color: c.outstandingAmount > 0 ? AppColors.dangerText : AppColors.successText),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: c.creditBalance > 0 ? AppColors.primary.withOpacity(0.08) : Colors.grey.shade50,
                        borderRadius: AppRadius.smBorderRadius,
                        border: Border.all(color: c.creditBalance > 0 ? AppColors.primary.withOpacity(0.3) : Colors.grey.shade200),
                      ),
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text('Customer Store Credit:', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                          Text(
                            Formatters.formatCurrency(c.creditBalance),
                            style: AppTextStyles.bodyBold.copyWith(color: c.creditBalance > 0 ? AppColors.primary : AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text('Sales & Invoices History', style: AppTextStyles.h2),
        const SizedBox(height: 12),
        ErpDataTable(
          columns: const [
            ErpColumn(title: 'Invoice Number'),
            ErpColumn(title: 'Date'),
            ErpColumn(title: 'Document Type'),
            ErpColumn(title: 'Total Invoiced', isNumeric: true),
            ErpColumn(title: 'Outstanding Due', isNumeric: true),
            ErpColumn(title: 'Status'),
          ],
          rows: customerSales.map((s) {
            return [
              InkWell(
                onTap: () => ref.read(activeRecordDetailsStackProvider.notifier).push(s.id, 'invoice', details.parentSection),
                child: Text(s.invoiceNumber, style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary)),
              ),
              Text(Formatters.formatDate(s.saleDate), style: AppTextStyles.bodySmall),
              Text(s.documentType.toString().split('.').last.toUpperCase(), style: AppTextStyles.bodySmall),
              Text(Formatters.formatCurrency(s.totalAmount), style: AppTextStyles.bodyBold),
              Text(
                Formatters.formatCurrency(s.pendingAmount),
                style: AppTextStyles.bodyBold.copyWith(color: s.pendingAmount > 0 ? AppColors.dangerText : AppColors.textMuted),
              ),
              Text(s.statusLabel, style: AppTextStyles.bodySmall),
            ];
          }).toList(),
        ),

        if (customerReturns.isNotEmpty) ...[
          const SizedBox(height: 28),
          Text('Sales Returns & Credit Notes', style: AppTextStyles.h2),
          const SizedBox(height: 12),
          ErpDataTable(
            columns: const [
              ErpColumn(title: 'Return No'),
              ErpColumn(title: 'Date'),
              ErpColumn(title: 'Original Invoice'),
              ErpColumn(title: 'Return Type'),
              ErpColumn(title: 'Total Amount', isNumeric: true),
              ErpColumn(title: 'Status'),
              ErpColumn(title: 'Refund / Credit Note'),
            ],
            rows: customerReturns.map((r) {
              return [
                InkWell(
                  onTap: () => ref.read(activeRecordDetailsStackProvider.notifier).push(r.id, 'salesReturn', details.parentSection),
                  child: Text(r.invoiceNumber, style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary)),
                ),
                Text(Formatters.formatDate(r.saleDate), style: AppTextStyles.bodySmall),
                Text(r.originalInvoiceNumber ?? '-', style: AppTextStyles.bodyMedium),
                Text(r.returnType == ReturnType.fullReturn ? 'Full' : 'Partial', style: AppTextStyles.bodySmall),
                Text(Formatters.formatCurrency(r.totalAmount), style: AppTextStyles.bodyBold),
                Text(r.salesReturnStatusLabel.toUpperCase(), style: AppTextStyles.bodySmall),
                Text(r.refundStatusLabel, style: AppTextStyles.bodySmall),
              ];
            }).toList(),
          ),
        ],
      ],
    );
  }

  // -----------------------------------------------------------------
  // 6. Dealer Details
  // -----------------------------------------------------------------
  Widget _buildDealerDetails(BuildContext context, WidgetRef ref, Dealer d, MockDatabaseService db) {
    final dealerSales = db.sales.where((s) => (s.partyId == d.id || s.partyName.toLowerCase() == d.name.toLowerCase()) && s.documentType != SalesDocumentType.salesReturn).toList();
    final sortedSales = List<Sale>.from(dealerSales)..sort((a, b) => b.saleDate.compareTo(a.saleDate));
    final dealerReturns = db.salesReturns.where((r) => r.partyId == d.id || r.partyName.toLowerCase() == d.name.toLowerCase()).toList();
    final grossInvoiced = dealerSales.where((s) => s.documentType == SalesDocumentType.invoice).fold(0.0, (sum, s) => sum + s.totalAmount);
    final approvedReturns = dealerReturns.where((r) => r.salesReturnStatus == SalesReturnStatus.approved).fold(0.0, (sum, r) => sum + r.totalAmount);
    final netSalesRevenue = (grossInvoiced - approvedReturns).clamp(0.0, double.infinity);
    final dealerPayments = db.payments.where((p) => p.partyId == d.id).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadius.lgBorderRadius,
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Dealer Profile', style: AppTextStyles.h3),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chat, color: Colors.green, size: 20),
                              tooltip: 'Quick WhatsApp Message',
                              onPressed: () => WhatsAppQuickChatDialog.showCustomerQuickChat(
                                context,
                                customerName: d.name,
                                customerPhone: d.mobile,
                              ),
                            ),
                            const SizedBox(width: 8),
                            ErpStatusBadge.neutral('ACTIVE DEALER'),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    _buildInfoRow('Dealer ID', d.id),
                    _buildInfoRow('Showroom / Store Name', d.name),
                    _buildInfoRow('Company Entity', d.companyName),
                    _buildInfoRow('Contact Person', d.contactPerson),
                    _buildInfoRow('Phone Number', d.mobile),
                    _buildInfoRow('Email Address', d.email.isNotEmpty ? d.email : '-'),
                    _buildInfoRow('GST Identification', d.gstNumber.isNotEmpty ? d.gstNumber : '-'),
                    _buildInfoRow('Showroom Address', d.address.isNotEmpty ? d.address : '-'),
                    _buildInfoRow('State', d.state.isNotEmpty ? d.state : '-'),
                    _buildInfoRow('PIN Code', d.pincode.isNotEmpty ? d.pincode : '-'),
                    _buildInfoRow('Account Created Date', Formatters.formatDate(d.createdAt)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadius.lgBorderRadius,
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Financial & Channel Ledger', style: AppTextStyles.h3),
                    const Divider(height: 24),
                    _buildInfoRow('Gross Sales Invoiced', Formatters.formatCurrency(grossInvoiced)),
                    _buildInfoRow('Approved Sales Returns', Formatters.formatCurrency(approvedReturns)),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Net Channel Revenue:', style: AppTextStyles.bodyBold),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(Formatters.formatCurrency(netSalesRevenue), textAlign: TextAlign.end, style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Receivables Due:', style: AppTextStyles.bodyMedium),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            Formatters.formatCurrency(d.outstandingAmount),
                            textAlign: TextAlign.end,
                            style: AppTextStyles.h2.copyWith(color: d.outstandingAmount > 0 ? AppColors.dangerText : AppColors.successText),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: d.outstandingAmount > 0 ? Colors.red.withValues(alpha: 0.08) : Colors.green.withValues(alpha: 0.08),
                        borderRadius: AppRadius.smBorderRadius,
                        border: Border.all(color: d.outstandingAmount > 0 ? Colors.red.withValues(alpha: 0.3) : Colors.green.withValues(alpha: 0.3)),
                      ),
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text('Account Standing:', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                          Text(
                            d.outstandingAmount > 0 ? 'PAYMENT OUTSTANDING' : 'CLEAR / CURRENT',
                            style: AppTextStyles.bodyBold.copyWith(color: d.outstandingAmount > 0 ? AppColors.dangerText : AppColors.successText),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text('Sales & Invoices History', style: AppTextStyles.h2),
        const SizedBox(height: 12),
        if (sortedSales.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: AppRadius.mdBorderRadius, border: Border.all(color: AppColors.border)),
            child: Text('No sales documents linked to this dealer showroom yet.', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
          )
        else
          ErpDataTable(
            columns: const [
              ErpColumn(title: 'Invoice Number'),
              ErpColumn(title: 'Date'),
              ErpColumn(title: 'Document Type'),
              ErpColumn(title: 'Total Invoiced', isNumeric: true),
              ErpColumn(title: 'Outstanding Due', isNumeric: true),
              ErpColumn(title: 'Status'),
              ErpColumn(title: 'Actions'),
            ],
            rows: sortedSales.map((s) {
              return [
                InkWell(
                  onTap: () => ref.read(activeRecordDetailsStackProvider.notifier).push(s.id, 'invoice', details.parentSection),
                  child: Text(s.invoiceNumber, style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary, decoration: TextDecoration.underline)),
                ),
                Text(Formatters.formatDate(s.saleDate), style: AppTextStyles.bodySmall),
                Text(s.documentType.toString().split('.').last.toUpperCase(), style: AppTextStyles.bodySmall),
                Text(Formatters.formatCurrency(s.totalAmount), style: AppTextStyles.bodyBold),
                Text(
                  Formatters.formatCurrency(s.pendingAmount),
                  style: AppTextStyles.bodyBold.copyWith(color: s.pendingAmount > 0 ? AppColors.dangerText : AppColors.textMuted),
                ),
                ErpStatusBadge.neutral(s.statusLabel.toUpperCase()),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.share, color: Colors.teal, size: 16),
                      tooltip: 'Share Document',
                      onPressed: () => ShareDocumentDialog.show(context, s),
                    ),
                    IconButton(
                      icon: const Icon(Icons.picture_as_pdf, color: AppColors.primary, size: 16),
                      tooltip: 'View PDF',
                      onPressed: () => SalesPdfGeneratorDialog.show(context, s, db),
                    ),
                  ],
                ),
              ];
            }).toList(),
          ),

        if (dealerReturns.isNotEmpty) ...[
          const SizedBox(height: 28),
          Text('Sales Returns & Credit Notes', style: AppTextStyles.h2),
          const SizedBox(height: 12),
          ErpDataTable(
            columns: const [
              ErpColumn(title: 'Return No'),
              ErpColumn(title: 'Date'),
              ErpColumn(title: 'Original Invoice'),
              ErpColumn(title: 'Return Type'),
              ErpColumn(title: 'Total Amount', isNumeric: true),
              ErpColumn(title: 'Status'),
              ErpColumn(title: 'Refund / Credit Note'),
            ],
            rows: dealerReturns.map((r) {
              return [
                InkWell(
                  onTap: () => ref.read(activeRecordDetailsStackProvider.notifier).push(r.id, 'salesReturn', details.parentSection),
                  child: Text(r.invoiceNumber, style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary, decoration: TextDecoration.underline)),
                ),
                Text(Formatters.formatDate(r.saleDate), style: AppTextStyles.bodySmall),
                Text(r.originalInvoiceNumber ?? '-', style: AppTextStyles.bodyMedium),
                Text(r.returnType == ReturnType.fullReturn ? 'Full' : 'Partial', style: AppTextStyles.bodySmall),
                Text(Formatters.formatCurrency(r.totalAmount), style: AppTextStyles.bodyBold),
                Text(r.salesReturnStatusLabel.toUpperCase(), style: AppTextStyles.bodySmall),
                Text(r.refundStatusLabel, style: AppTextStyles.bodySmall),
              ];
            }).toList(),
          ),
        ],

        if (dealerPayments.isNotEmpty) ...[
          const SizedBox(height: 28),
          Text('Payment Receipts & Settlements', style: AppTextStyles.h2),
          const SizedBox(height: 12),
          ErpDataTable(
            columns: const [
              ErpColumn(title: 'Payment No'),
              ErpColumn(title: 'Payment Date'),
              ErpColumn(title: 'Reference / UTR'),
              ErpColumn(title: 'Invoice Reference'),
              ErpColumn(title: 'Amount (₹)', isNumeric: true),
              ErpColumn(title: 'Payment Mode'),
              ErpColumn(title: 'Status'),
            ],
            rows: dealerPayments.map((p) {
              return [
                Text(p.paymentNumber, style: AppTextStyles.bodyBold),
                Text(Formatters.formatDate(p.paymentDate), style: AppTextStyles.bodySmall),
                Text(p.transactionReference ?? '-', style: AppTextStyles.bodySmall),
                Text(p.referenceDocumentNumber ?? '-', style: AppTextStyles.bodySmall),
                Text(Formatters.formatCurrency(p.amount), style: AppTextStyles.bodyBold.copyWith(color: AppColors.successText)),
                Text(p.paymentMode.name.toUpperCase(), style: AppTextStyles.bodySmall),
                p.isFullPayment ? ErpStatusBadge.success('FULL') : ErpStatusBadge.warning('PARTIAL'),
              ];
            }).toList(),
          ),
        ],
      ],
    );
  }

  // -----------------------------------------------------------------
  // 7. Architect Details
  // -----------------------------------------------------------------
  Widget _buildArchitectDetails(BuildContext context, WidgetRef ref, Architect a, MockDatabaseService db) {
    // 1. Relational Queries
    final linkedCust = a.linkedCustomerId != null
        ? db.customers.where((c) => c.id == a.linkedCustomerId).firstOrNull
        : null;

    final architectProjects = db.projects.where((p) =>
        p.architectId == a.id ||
        (linkedCust != null && p.customerId == linkedCust.id)).toList();

    final projectIds = architectProjects.map((p) => p.id).toSet();

    final architectCommissions = db.commissions.where((c) => c.architectId == a.id).toList();

    final architectSales = db.sales.where((s) =>
        s.architectId == a.id ||
        (s.projectId != null && projectIds.contains(s.projectId)) ||
        (linkedCust != null && s.partyId == linkedCust.id)).toList();

    final architectQuotations = architectSales.where((s) => s.documentType == SalesDocumentType.quotation).toList();
    final architectInvoices = architectSales.where((s) =>
        s.documentType == SalesDocumentType.invoice || s.documentType == SalesDocumentType.salesOrder).toList();
    final sortedInvoices = List<Sale>.from(architectInvoices)..sort((a, b) => b.saleDate.compareTo(a.saleDate));

    final architectPurchases = db.purchases.where((p) =>
        p.projectId != null && projectIds.contains(p.projectId)).toList();

    final architectProductions = db.productionOrders.where((po) =>
        (po.projectId != null && projectIds.contains(po.projectId)) ||
        (po.salesOrderId != null && architectSales.any((s) => s.id == po.salesOrderId))).toList();

    final commissionPayments = db.payments.where((pay) =>
        pay.partyId == a.id && pay.paymentType == PaymentType.commissionPayment).toList();

    // Commission Metrics
    final commEarned = architectCommissions.where((c) => c.status != CommissionStatus.rejected).fold(0.0, (s, c) => s + c.commissionAmount);
    final commPending = architectCommissions.where((c) => c.status == CommissionStatus.generated).fold(0.0, (s, c) => s + c.commissionAmount);
    final commApproved = architectCommissions.where((c) => c.status == CommissionStatus.approved).fold(0.0, (s, c) => s + c.commissionAmount);
    final commPaid = architectCommissions.where((c) => c.status == CommissionStatus.paid).fold(0.0, (s, c) => s + c.commissionAmount);

    final invComms = architectInvoices
        .where((s) => s.documentType == SalesDocumentType.invoice && s.status != SaleStatus.cancelled)
        .fold(0.0, (s, sale) => s + sale.architectCommissionAmount);

    final displayTotalGenerated = commEarned > 0 ? commEarned : (a.totalCommissionEarned > 0 ? a.totalCommissionEarned : invComms);
    final displayPendingReview = commPending > 0 ? commPending : (a.pendingCommission > 0 ? a.pendingCommission : (commEarned == 0 ? invComms : 0.0));
    final displayApprovedPayouts = commApproved > 0 ? commApproved : a.approvedCommission;
    final displayPaidToDate = commPaid > 0 ? commPaid : a.paidCommission;

    // 2. Raw Material Consumption calculations
    final rawMaterialsList = <Map<String, dynamic>>[];
    for (final po in architectProductions) {
      for (final rm in po.rawMaterialsUsed) {
        final lineCost = rm.totalCost > 0 ? rm.totalCost : (rm.quantityUsed * rm.unitCost);
        rawMaterialsList.add({
          'name': rm.rawMaterialName,
          'code': rm.rawMaterialCode,
          'project': po.projectName ?? 'Project Production',
          'projectId': po.projectId,
          'quantity': rm.quantityUsed,
          'unit': rm.unit,
          'date': po.productionDate,
          'unitCost': rm.unitCost,
          'totalCost': lineCost,
          'source': po.productionNumber,
        });
      }
    }

    // 3. Finished Product Usage calculations
    final finishedProductsList = <Map<String, dynamic>>[];
    for (final s in architectInvoices) {
      for (final it in s.items) {
        final fp = db.finishedProducts.where((f) => f.id == it.finishedProductId).firstOrNull;
        final isPurchased = fp != null ? (fp.purchasedStock > fp.producedStock) : false;
        final costPerUnit = fp != null ? fp.costPrice : (it.rate * 0.7);
        final usageQty = it.deliveredQuantity > 0 ? it.deliveredQuantity : it.quantity;
        final totalItemCost = usageQty * costPerUnit;

        finishedProductsList.add({
          'name': it.finishedProductName,
          'code': it.finishedProductCode.isNotEmpty ? it.finishedProductCode : (fp?.itemCode ?? '-'),
          'project': s.projectName ?? 'Direct Client Order',
          'projectId': s.projectId,
          'quantity': usageQty,
          'unit': it.unit,
          'source': isPurchased ? 'Purchased' : 'Produced',
          'unitCost': costPerUnit,
          'totalCost': totalItemCost,
          'date': s.saleDate,
          'sourceDoc': s.invoiceNumber,
        });
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Dual Top Profile Cards
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Card: Architect Profile
            Expanded(
              flex: 3,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadius.lgBorderRadius,
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Architect Profile', style: AppTextStyles.h3),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chat, color: Colors.green, size: 20),
                              tooltip: 'Quick WhatsApp Message',
                              onPressed: () => WhatsAppQuickChatDialog.showArchitectQuickChat(
                                context,
                                architectName: a.name,
                                architectPhone: a.mobile,
                                firmName: a.companyName,
                              ),
                            ),
                            const SizedBox(width: 8),
                            ErpStatusBadge.neutral('ACTIVE PARTNER'),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    _buildInfoRow('Architect ID', a.id),
                    _buildInfoRow('Architect Name', a.name),
                    _buildInfoRow('Studio / Company Name', a.companyName.isNotEmpty ? a.companyName : '-'),
                    _buildInfoRow('Mobile Number', a.mobile),
                    _buildInfoRow('Email Address', a.email.isNotEmpty ? a.email : '-'),
                    _buildInfoRow('Studio Address', a.address.isNotEmpty ? a.address : '-'),
                    _buildInfoRow('State', a.state.isNotEmpty ? a.state : '-'),
                    _buildInfoRow('PIN Code', a.pincode.isNotEmpty ? a.pincode : '-'),
                    _buildInfoRow('GST Number', a.gstNumber.isNotEmpty ? a.gstNumber : '-'),
                    _buildInfoRow('Partner Registered Date', Formatters.formatDate(DateTime.now().subtract(const Duration(days: 120)))),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Architect-Customer Link:', style: AppTextStyles.bodyMedium),
                        linkedCust != null
                            ? InkWell(
                                onTap: () {
                                  ref.read(activeRecordDetailsStackProvider.notifier).push(linkedCust.id, 'customer', details.parentSection);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.link, size: 14, color: Colors.purple),
                                      const SizedBox(width: 6),
                                      Text(
                                        linkedCust.name,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.purple,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('Not Linked to Customer Master', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Right Card: Commission & Financial Ledger
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadius.lgBorderRadius,
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Commission & Financial Ledger', style: AppTextStyles.h3),
                    const Divider(height: 24),
                    _buildInfoRow('Default Commission Rate', '${a.defaultCommissionRate}%'),
                    _buildInfoRow('Associated Projects', '${architectProjects.length} Projects'),
                    _buildInfoRow('Total Commission Generated', Formatters.formatCurrency(displayTotalGenerated)),
                    _buildInfoRow('Approved Payouts', Formatters.formatCurrency(displayApprovedPayouts)),
                    _buildInfoRow('Disbursed to Date', Formatters.formatCurrency(displayPaidToDate)),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Pending Review / Due:', style: AppTextStyles.bodyBold),
                        Text(
                          Formatters.formatCurrency(displayPendingReview),
                          style: AppTextStyles.h2.copyWith(
                            color: displayPendingReview > 0 ? Colors.purple : AppColors.successText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.purple.withValues(alpha: 0.08),
                        borderRadius: AppRadius.smBorderRadius,
                        border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Partner Payout Status:', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                          Text(
                            displayPendingReview > 0 ? 'PAYOUT PENDING' : 'SETTLED',
                            style: AppTextStyles.bodyBold.copyWith(
                              color: displayPendingReview > 0 ? Colors.purple : AppColors.successText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        // Linked Direct Customer Account Details (Dual Entity)
        if (linkedCust != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.purple.withValues(alpha: 0.04),
              borderRadius: AppRadius.lgBorderRadius,
              border: Border.all(color: Colors.purple.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person_pin_circle, color: Colors.purple, size: 22),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('Linked Customer Account: ', style: AppTextStyles.bodyMedium),
                            Text(linkedCust.name, style: AppTextStyles.bodyBold.copyWith(color: Colors.purple)),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Contact: ${linkedCust.mobile}   •   GSTIN: ${linkedCust.gstNumber.isNotEmpty ? linkedCust.gstNumber : "-"}   •   Email: ${linkedCust.email.isNotEmpty ? linkedCust.email : "-"}   •   Outstanding: ${Formatters.formatCurrency(linkedCust.outstandingAmount)}',
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
                InkWell(
                  onTap: () => ref.read(activeRecordDetailsStackProvider.notifier).push(linkedCust.id, 'customer', details.parentSection),
                  child: Text('Open Customer Profile →',
                      style: AppTextStyles.bodyBold.copyWith(color: Colors.purple, decoration: TextDecoration.underline)),
                ),
              ],
            ),
          ),
        ],

        // Associated Architectural Projects
        const SizedBox(height: 24),
        Text('Associated Projects', style: AppTextStyles.h2),
        const SizedBox(height: 12),
        if (architectProjects.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: AppRadius.mdBorderRadius, border: Border.all(color: AppColors.border)),
            child: Text('No projects currently linked to this Architect.', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
          )
        else
          ErpDataTable(
            columns: const [
              ErpColumn(title: 'Project Name'),
              ErpColumn(title: 'Project ID'),
              ErpColumn(title: 'Client / Customer'),
              ErpColumn(title: 'Status'),
              ErpColumn(title: 'Start Date'),
              ErpColumn(title: 'Project Value (₹)', isNumeric: true),
              ErpColumn(title: 'Amount Billed (₹)', isNumeric: true),
              ErpColumn(title: 'Amount Received (₹)', isNumeric: true),
            ],
            rows: architectProjects.map((p) {
              final prjSales = db.sales.where((s) => s.projectId == p.id).toList();
              final billed = prjSales.fold(0.0, (sum, s) => sum + s.totalAmount);
              final received = prjSales.fold(0.0, (sum, s) => sum + s.paidAmount);

              return [
                InkWell(
                  onTap: () => ref.read(activeRecordDetailsStackProvider.notifier).push(p.id, 'project', details.parentSection),
                  child: Text(p.name, style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary, decoration: TextDecoration.underline)),
                ),
                Text(p.id, style: AppTextStyles.bodySmall),
                Text(p.customerName ?? linkedCust?.name ?? 'Direct Client', style: AppTextStyles.bodyMedium),
                ErpStatusBadge.neutral(p.statusLabel),
                Text(Formatters.formatDate(p.startDate), style: AppTextStyles.bodySmall),
                Text(Formatters.formatCurrency(p.totalSalesAmount), style: AppTextStyles.bodyBold),
                Text(Formatters.formatCurrency(billed), style: AppTextStyles.bodyMedium),
                Text(Formatters.formatCurrency(received), style: AppTextStyles.bodyBold.copyWith(color: AppColors.successText)),
              ];
            }).toList(),
          ),

        // Sales & Invoices History
        const SizedBox(height: 28),
        Text('Sales & Invoices History', style: AppTextStyles.h2),
        const SizedBox(height: 12),
        if (sortedInvoices.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: AppRadius.mdBorderRadius, border: Border.all(color: AppColors.border)),
            child: Text('No sales invoices linked to this Architect.', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
          )
        else
          ErpDataTable(
            columns: const [
              ErpColumn(title: 'Invoice / Order No'),
              ErpColumn(title: 'Client / Customer'),
              ErpColumn(title: 'Project'),
              ErpColumn(title: 'Invoice Date'),
              ErpColumn(title: 'Taxable Amount (₹)', isNumeric: true),
              ErpColumn(title: 'Grand Total (₹)', isNumeric: true),
              ErpColumn(title: 'Paid Amount (₹)', isNumeric: true),
              ErpColumn(title: 'Balance Pending (₹)', isNumeric: true),
              ErpColumn(title: 'Payment Status'),
            ],
            rows: sortedInvoices.map((s) {
              return [
                InkWell(
                  onTap: () => ref.read(activeRecordDetailsStackProvider.notifier).push(s.id, 'invoice', details.parentSection),
                  child: Text(s.invoiceNumber, style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary, decoration: TextDecoration.underline)),
                ),
                Text(s.partyName, style: AppTextStyles.bodyMedium),
                Text(s.projectName ?? '-', style: AppTextStyles.bodySmall),
                Text(Formatters.formatDate(s.saleDate), style: AppTextStyles.bodySmall),
                Text(Formatters.formatCurrency(s.taxableAmount), style: AppTextStyles.bodySmall),
                Text(Formatters.formatCurrency(s.totalAmount), style: AppTextStyles.bodyBold),
                Text(Formatters.formatCurrency(s.paidAmount), style: AppTextStyles.bodyMedium.copyWith(color: AppColors.successText)),
                Text(Formatters.formatCurrency(s.pendingAmount), style: AppTextStyles.bodyBold.copyWith(color: s.pendingAmount > 0 ? AppColors.dangerText : AppColors.successText)),
                ErpStatusBadge.neutral(s.statusLabel),
              ];
            }).toList(),
          ),

        // Commission Vouchers & Payout Lifecycle
        const SizedBox(height: 28),
        Text('Commission Vouchers & Payout Lifecycle', style: AppTextStyles.h2),
        const SizedBox(height: 12),
        if (architectCommissions.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: AppRadius.mdBorderRadius, border: Border.all(color: AppColors.border)),
            child: Text('No commission vouchers recorded for this partner.', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
          )
        else
          ErpDataTable(
            columns: const [
              ErpColumn(title: 'Voucher No'),
              ErpColumn(title: 'Generated Date'),
              ErpColumn(title: 'Linked Sale Invoice'),
              ErpColumn(title: 'Project'),
              ErpColumn(title: 'Sale Net Valuation', isNumeric: true),
              ErpColumn(title: 'Rate', isNumeric: true),
              ErpColumn(title: 'Commission Amount (₹)', isNumeric: true),
              ErpColumn(title: 'Lifecycle Status'),
              ErpColumn(title: 'Workflow Actions'),
            ],
            rows: architectCommissions.map((comm) {
              ErpStatusBadge badge;
              switch (comm.status) {
                case CommissionStatus.generated:
                  badge = ErpStatusBadge.warning('PENDING REVIEW');
                  break;
                case CommissionStatus.approved:
                  badge = ErpStatusBadge.info('APPROVED');
                  break;
                case CommissionStatus.paid:
                  badge = ErpStatusBadge.success('PAID');
                  break;
                case CommissionStatus.rejected:
                  badge = ErpStatusBadge.danger('REJECTED');
                  break;
              }

              return [
                Text(comm.commissionNumber, style: AppTextStyles.bodyBold),
                Text(Formatters.formatDate(comm.generatedDate), style: AppTextStyles.bodySmall),
                InkWell(
                  onTap: () => ref.read(activeRecordDetailsStackProvider.notifier).push(comm.saleInvoiceId, 'invoice', details.parentSection),
                  child: Text(comm.saleInvoiceNumber, style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary)),
                ),
                Text(comm.projectName ?? '-', style: AppTextStyles.bodySmall),
                Text(Formatters.formatCurrency(comm.saleAmount), style: AppTextStyles.bodySmall),
                Text('${comm.commissionRate}%', style: AppTextStyles.bodySmall),
                Text(Formatters.formatCurrency(comm.commissionAmount), style: AppTextStyles.bodyBold.copyWith(color: AppColors.purple)),
                badge,
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (comm.status == CommissionStatus.generated) ...[
                      IconButton(
                        icon: const Icon(Icons.check_circle_outline, color: Colors.green, size: 18),
                        tooltip: 'Approve Commission Voucher',
                        onPressed: () async {
                          try {
                            await db.approveCommissionAsync(comm.id);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text('Commission Voucher ${comm.commissionNumber} Approved!'),
                                backgroundColor: AppColors.success,
                              ));
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text('Failed to approve: $e'),
                                backgroundColor: AppColors.danger,
                              ));
                            }
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.cancel_outlined, color: Colors.red, size: 18),
                        tooltip: 'Reject Commission Voucher',
                        onPressed: () async {
                          try {
                            await db.rejectCommissionAsync(comm.id, reason: 'Declined during partner audit');
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text('Commission Voucher ${comm.commissionNumber} Rejected.'),
                                backgroundColor: AppColors.danger,
                              ));
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text('Failed to reject: $e'),
                                backgroundColor: AppColors.danger,
                              ));
                            }
                          }
                        },
                      ),
                    ],
                    if (comm.status == CommissionStatus.approved) ...[
                      IconButton(
                        icon: const Icon(Icons.payments_outlined, color: Colors.purple, size: 18),
                        tooltip: 'Disburse / Pay Commission',
                        onPressed: () async {
                          try {
                            await db.disburseCommissionAsync(
                              commissionId: comm.id,
                              paymentMode: PaymentMode.bankTransfer,
                              transactionRef: 'TXN-DISB-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text('Disbursed ${Formatters.formatCurrency(comm.commissionAmount)} to ${comm.architectName}!'),
                                backgroundColor: AppColors.success,
                              ));
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text('Failed to disburse: $e'),
                                backgroundColor: AppColors.danger,
                              ));
                            }
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.cancel_outlined, color: Colors.red, size: 18),
                        tooltip: 'Reject / Cancel Commission Voucher',
                        onPressed: () async {
                          try {
                            await db.rejectCommissionAsync(comm.id, reason: 'Declined after approval');
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text('Commission Voucher ${comm.commissionNumber} Rejected.'),
                                backgroundColor: AppColors.danger,
                              ));
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text('Failed to reject: $e'),
                                backgroundColor: AppColors.danger,
                              ));
                            }
                          }
                        },
                      ),
                    ],
                  ],
                ),
              ];
            }).toList(),
          ),

        // Commission Disbursement History
        if (commissionPayments.isNotEmpty) ...[
          const SizedBox(height: 28),
          Text('Commission Disbursement History', style: AppTextStyles.h2),
          const SizedBox(height: 12),
          ErpDataTable(
            columns: const [
              ErpColumn(title: 'Payment No'),
              ErpColumn(title: 'Payment Date'),
              ErpColumn(title: 'Reference / UTR'),
              ErpColumn(title: 'Commission Voucher'),
              ErpColumn(title: 'Payment Mode'),
              ErpColumn(title: 'Disbursed Amount (₹)', isNumeric: true),
              ErpColumn(title: 'Status'),
            ],
            rows: commissionPayments.map((p) {
              return [
                Text(p.paymentNumber, style: AppTextStyles.bodyBold),
                Text(Formatters.formatDate(p.paymentDate), style: AppTextStyles.bodySmall),
                Text(p.transactionReference ?? '-', style: AppTextStyles.bodySmall),
                Text(p.referenceDocumentNumber ?? '-', style: AppTextStyles.bodyBold.copyWith(color: AppColors.purple)),
                Text(p.paymentMode.name.toUpperCase(), style: AppTextStyles.bodySmall),
                Text(Formatters.formatCurrency(p.amount), style: AppTextStyles.bodyBold.copyWith(color: AppColors.successText)),
                ErpStatusBadge.success('DISBURSED'),
              ];
            }).toList(),
          ),
        ],

        // Quotations & Estimates
        if (architectQuotations.isNotEmpty) ...[
          const SizedBox(height: 28),
          Text('Quotations & Estimates', style: AppTextStyles.h2),
          const SizedBox(height: 12),
          ErpDataTable(
            columns: const [
              ErpColumn(title: 'Quotation No'),
              ErpColumn(title: 'Client / Customer'),
              ErpColumn(title: 'Project'),
              ErpColumn(title: 'Quotation Date'),
              ErpColumn(title: 'Total Amount (₹)', isNumeric: true),
              ErpColumn(title: 'Status'),
            ],
            rows: architectQuotations.map((q) {
              return [
                InkWell(
                  onTap: () => ref.read(activeRecordDetailsStackProvider.notifier).push(q.id, 'quotation', details.parentSection),
                  child: Text(q.invoiceNumber, style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary, decoration: TextDecoration.underline)),
                ),
                Text(q.partyName, style: AppTextStyles.bodyMedium),
                Text(q.projectName ?? '-', style: AppTextStyles.bodySmall),
                Text(Formatters.formatDate(q.saleDate), style: AppTextStyles.bodySmall),
                Text(Formatters.formatCurrency(q.totalAmount), style: AppTextStyles.bodyBold),
                ErpStatusBadge.neutral(q.statusLabel),
              ];
            }).toList(),
          ),
        ],

        // Direct Purchases in Architect Projects
        if (architectPurchases.isNotEmpty) ...[
          const SizedBox(height: 28),
          Text('Direct Purchases in Architect Projects', style: AppTextStyles.h2),
          const SizedBox(height: 12),
          ErpDataTable(
            columns: const [
              ErpColumn(title: 'PO Number'),
              ErpColumn(title: 'Date'),
              ErpColumn(title: 'Vendor'),
              ErpColumn(title: 'Purchase Type'),
              ErpColumn(title: 'Items Count', isNumeric: true),
              ErpColumn(title: 'Total Amount (₹)', isNumeric: true),
              ErpColumn(title: 'Status'),
            ],
            rows: architectPurchases.map((p) {
              final isFinished = p.items.any((it) => it.itemType == PurchaseItemType.finishedProduct);
              return [
                InkWell(
                  onTap: () => ref.read(activeRecordDetailsStackProvider.notifier).push(p.id, 'purchase', details.parentSection),
                  child: Text(p.purchaseNumber, style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary, decoration: TextDecoration.underline)),
                ),
                Text(Formatters.formatDate(p.purchaseDate), style: AppTextStyles.bodySmall),
                Text(p.vendorName, style: AppTextStyles.bodyMedium),
                Text(isFinished ? 'Finished Goods' : 'Raw Material', style: TextStyle(fontSize: 11, color: isFinished ? Colors.teal : Colors.blueGrey, fontWeight: FontWeight.bold)),
                Text('${p.items.length} items', style: AppTextStyles.bodySmall),
                Text(Formatters.formatCurrency(p.totalAmount), style: AppTextStyles.bodyBold),
                ErpStatusBadge.neutral(p.statusLabel),
              ];
            }).toList(),
          ),
        ],

        // Factory Production Orders
        if (architectProductions.isNotEmpty) ...[
          const SizedBox(height: 28),
          Text('Factory Production Orders for Architect Projects', style: AppTextStyles.h2),
          const SizedBox(height: 12),
          ErpDataTable(
            columns: const [
              ErpColumn(title: 'Production No'),
              ErpColumn(title: 'Project'),
              ErpColumn(title: 'Production Date'),
              ErpColumn(title: 'Finished Product'),
              ErpColumn(title: 'Qty Produced', isNumeric: true),
              ErpColumn(title: 'RM Cost (₹)', isNumeric: true),
              ErpColumn(title: 'Labour & Overheads (₹)', isNumeric: true),
              ErpColumn(title: 'Total Production Cost (₹)', isNumeric: true),
            ],
            rows: architectProductions.map((po) {
              return [
                Text(po.productionNumber, style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary)),
                Text(po.projectName ?? 'Project Scope', style: AppTextStyles.bodySmall),
                Text(Formatters.formatDate(po.productionDate), style: AppTextStyles.bodySmall),
                Text(po.finishedProductName, style: AppTextStyles.bodyMedium),
                Text('${Formatters.formatNumber(po.actualQuantityProduced)} ${po.unit}', style: AppTextStyles.bodyBold),
                Text(Formatters.formatCurrency(po.rawMaterialCost), style: AppTextStyles.bodySmall),
                Text(Formatters.formatCurrency(po.labourCost + po.otherExpenses), style: AppTextStyles.bodySmall),
                Text(Formatters.formatCurrency(po.totalProductionCost), style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary)),
              ];
            }).toList(),
          ),
        ],

        // Raw Material Consumption
        if (rawMaterialsList.isNotEmpty) ...[
          const SizedBox(height: 28),
          Text('Raw Material Consumption in Architect Projects', style: AppTextStyles.h2),
          const SizedBox(height: 12),
          ErpDataTable(
            columns: const [
              ErpColumn(title: 'Material Name'),
              ErpColumn(title: 'Item Code'),
              ErpColumn(title: 'Project Name'),
              ErpColumn(title: 'Quantity Used', isNumeric: true),
              ErpColumn(title: 'Unit'),
              ErpColumn(title: 'Date Used'),
              ErpColumn(title: 'Unit Cost (₹)', isNumeric: true),
              ErpColumn(title: 'Total Cost (₹)', isNumeric: true),
              ErpColumn(title: 'Source Transaction'),
            ],
            rows: rawMaterialsList.map((rm) {
              return [
                Text(rm['name'] as String, style: AppTextStyles.bodyBold),
                Text(rm['code'] as String, style: AppTextStyles.bodySmall),
                Text(rm['project'] as String, style: AppTextStyles.bodyMedium),
                Text(Formatters.formatNumber(rm['quantity'] as double), style: AppTextStyles.bodyBold),
                Text(rm['unit'] as String, style: AppTextStyles.bodySmall),
                Text(Formatters.formatDate(rm['date'] as DateTime), style: AppTextStyles.bodySmall),
                Text(Formatters.formatCurrency(rm['unitCost'] as double), style: AppTextStyles.bodySmall),
                Text(Formatters.formatCurrency(rm['totalCost'] as double), style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary)),
                Text(rm['source'] as String, style: AppTextStyles.bodySmall.copyWith(color: AppColors.purple)),
              ];
            }).toList(),
          ),
        ],

        // Finished Goods Delivered & Used
        if (finishedProductsList.isNotEmpty) ...[
          const SizedBox(height: 28),
          Text('Finished Goods Delivered & Used in Projects', style: AppTextStyles.h2),
          const SizedBox(height: 12),
          ErpDataTable(
            columns: const [
              ErpColumn(title: 'Product Name'),
              ErpColumn(title: 'SKU / Code'),
              ErpColumn(title: 'Project Name'),
              ErpColumn(title: 'Quantity Used', isNumeric: true),
              ErpColumn(title: 'Unit'),
              ErpColumn(title: 'Source'),
              ErpColumn(title: 'Unit Cost (₹)', isNumeric: true),
              ErpColumn(title: 'Total Cost (₹)', isNumeric: true),
              ErpColumn(title: 'Delivery / Sale Date'),
            ],
            rows: finishedProductsList.map((fp) {
              final isPurchased = fp['source'] == 'Purchased';
              return [
                Text(fp['name'] as String, style: AppTextStyles.bodyBold),
                Text(fp['code'] as String, style: AppTextStyles.bodySmall),
                Text(fp['project'] as String, style: AppTextStyles.bodyMedium),
                Text(Formatters.formatNumber(fp['quantity'] as double), style: AppTextStyles.bodyBold),
                Text(fp['unit'] as String, style: AppTextStyles.bodySmall),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isPurchased ? Colors.teal.withValues(alpha: 0.1) : Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isPurchased ? 'Purchased Goods' : 'Produced Goods',
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: isPurchased ? Colors.teal : Colors.blue),
                  ),
                ),
                Text(Formatters.formatCurrency(fp['unitCost'] as double), style: AppTextStyles.bodySmall),
                Text(Formatters.formatCurrency(fp['totalCost'] as double), style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary)),
                Text(Formatters.formatDate(fp['date'] as DateTime), style: AppTextStyles.bodySmall),
              ];
            }).toList(),
          ),
        ],

        // Partner Activity Timeline (Commented out per request)
        /*
        const SizedBox(height: 28),
        Text('Partner Activity Timeline & Audit Trail', style: AppTextStyles.h2),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.lgBorderRadius,
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              _buildTimelineTile('Partner Master Created', 'Registered Architect partner ${a.name} (${a.companyName}) with default commission rate of ${a.defaultCommissionRate}%.', DateTime.now().subtract(const Duration(days: 90)), Icons.person_add_alt_1, Colors.blue),
              if (linkedCust != null)
                _buildTimelineTile('Customer Entity Linked', 'Linked direct Customer account "${linkedCust.name}" for unified project quotation and billing scope.', DateTime.now().subtract(const Duration(days: 85)), Icons.link, Colors.purple),
              ...architectProjects.map((prj) => _buildTimelineTile('Project Initiated', 'Assigned design and architectural scope for Project "${prj.name}" (Valuation: ${Formatters.formatCurrency(prj.totalSalesAmount)}).', prj.startDate, Icons.apartment, Colors.indigo)),
              ...architectQuotations.map((q) => _buildTimelineTile('Estimate / Quotation Created', 'Generated Quotation ${q.invoiceNumber} for ${q.partyName} (Value: ${Formatters.formatCurrency(q.totalAmount)}).', q.saleDate, Icons.description_outlined, Colors.orange)),
              ...architectInvoices.map((inv) => _buildTimelineTile('Tax Invoice Issued', 'Billed Tax Invoice ${inv.invoiceNumber} (Total: ${Formatters.formatCurrency(inv.totalAmount)} | Status: ${inv.statusLabel}).', inv.saleDate, Icons.receipt_long, Colors.teal)),
              ...architectCommissions.map((comm) => _buildTimelineTile('Commission Voucher Generated', 'Generated commission ${comm.commissionNumber} of ${Formatters.formatCurrency(comm.commissionAmount)} on Invoice ${comm.saleInvoiceNumber}.', comm.generatedDate, Icons.monetization_on, Colors.purple)),
              ...commissionPayments.map((pay) => _buildTimelineTile('Commission Disbursed', 'Disbursed ${Formatters.formatCurrency(pay.amount)} via ${pay.paymentMode.name.toUpperCase()} (Ref: ${pay.transactionReference ?? "-"}).', pay.paymentDate, Icons.check_circle, Colors.green)),
            ],
          ),
        ),
        */
      ],
    );
  }

  /*
  Widget _buildTimelineTile(String title, String description, DateTime timestamp, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title, style: AppTextStyles.bodyBold.copyWith(fontSize: 13)),
                    Text(Formatters.formatDate(timestamp), style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
                  ],
                ),
                const SizedBox(height: 3),
                Text(description, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
  */

  // -----------------------------------------------------------------
  // 8. Project Details (Comprehensive 10-Section Breakdown: A to J)
  // -----------------------------------------------------------------
  Widget _buildProjectDetails(BuildContext context, WidgetRef ref, Project prj, MockDatabaseService db) {
    // 1. Gather all linked entities
    final projectSales = db.sales.where((s) => s.projectId == prj.id).toList();
    final projectPurchases = db.purchases.where((p) => p.projectId == prj.id).toList();
    final projectProductions = db.productionOrders.where((po) => po.projectId == prj.id).toList();
    final projectExpenses = db.expenses.where((e) => e.projectId == prj.id).toList();
    final projectPayments = db.payments.where((pay) => pay.projectId == prj.id).toList();

    // Raw Material Consumption
    final rawMaterialConsumption = <String, Map<String, dynamic>>{};
    for (final po in projectProductions) {
      for (final rm in po.rawMaterialsUsed) {
        if (!rawMaterialConsumption.containsKey(rm.rawMaterialId)) {
          rawMaterialConsumption[rm.rawMaterialId] = {
            'name': rm.rawMaterialName,
            'code': rm.rawMaterialCode,
            'unit': rm.unit,
            'quantity': 0.0,
            'totalCost': 0.0,
          };
        }
        rawMaterialConsumption[rm.rawMaterialId]!['quantity'] =
            (rawMaterialConsumption[rm.rawMaterialId]!['quantity'] as double) + rm.quantityUsed;
        rawMaterialConsumption[rm.rawMaterialId]!['totalCost'] =
            (rawMaterialConsumption[rm.rawMaterialId]!['totalCost'] as double) + rm.totalCost;
      }
    }

    // Finished Product Usage
    final finishedProductUsage = <String, Map<String, dynamic>>{};
    for (final s in projectSales) {
      for (final item in s.items) {
        if (!finishedProductUsage.containsKey(item.finishedProductId)) {
          finishedProductUsage[item.finishedProductId] = {
            'name': item.finishedProductName,
            'code': item.finishedProductCode,
            'unit': item.unit,
            'quantity': 0.0,
            'totalValue': 0.0,
          };
        }
        finishedProductUsage[item.finishedProductId]!['quantity'] =
            (finishedProductUsage[item.finishedProductId]!['quantity'] as double) + item.quantity;
        finishedProductUsage[item.finishedProductId]!['totalValue'] =
            (finishedProductUsage[item.finishedProductId]!['totalValue'] as double) + item.lineTotal;
      }
    }

    // Project Stock Movements
    final linkedProductIds = finishedProductUsage.keys.toSet()..addAll(rawMaterialConsumption.keys);
    final projectMovements = db.stockMovements.where((m) => linkedProductIds.contains(m.itemId)).toList();

    // Financial Metrics
    final totalSalesInvoiced = projectSales
        .where((s) => s.documentType == SalesDocumentType.invoice)
        .fold(0.0, (sum, s) => sum + s.totalAmount);
    final totalSalesPending = projectSales
        .where((s) => s.documentType == SalesDocumentType.invoice)
        .fold(0.0, (sum, s) => sum + s.pendingAmount);
    final totalProjectExpenses = projectExpenses.fold(0.0, (sum, e) => sum + e.amount);
    final totalProjectPurchases = projectPurchases.fold(0.0, (sum, p) => sum + p.totalAmount);
    final estimatedMargin = (totalSalesInvoiced - totalProjectExpenses - totalProjectPurchases).clamp(-9999999.0, 99999999.0);
    final sortedSales = List<Sale>.from(projectSales)..sort((a, b) => b.saleDate.compareTo(a.saleDate));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadius.lgBorderRadius,
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Project Details', style: AppTextStyles.h3),
                        Row(
                          children: [
                            if (prj.customerId != null)
                              IconButton(
                                icon: const Icon(Icons.chat, color: Colors.green, size: 20),
                                tooltip: 'WhatsApp Client / Site Lead',
                                onPressed: () => WhatsAppQuickChatDialog.showCustomerQuickChat(
                                  context,
                                  customerName: prj.customerName ?? prj.name,
                                  customerPhone: '+91 98765 00000',
                                  projectName: prj.name,
                                ),
                              ),
                            const SizedBox(width: 8),
                            ErpStatusBadge.neutral(prj.statusLabel.toUpperCase()),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    _buildInfoRow('Project Code', prj.id),
                    _buildInfoRow('Project Name', prj.name),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Client / Customer:', style: AppTextStyles.bodyMedium),
                        if (prj.customerId != null)
                          InkWell(
                            onTap: () => ref.read(activeRecordDetailsStackProvider.notifier).push(prj.customerId!, 'customer', details.parentSection),
                            child: Text(prj.customerName ?? 'Direct Client', style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary, decoration: TextDecoration.underline)),
                          )
                        else
                          Text('Direct Client', style: AppTextStyles.bodyBold),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Lead Architect / Specifier:', style: AppTextStyles.bodyMedium),
                        if (prj.architectId != null)
                          InkWell(
                            onTap: () => ref.read(activeRecordDetailsStackProvider.notifier).push(prj.architectId!, 'architect', details.parentSection),
                            child: Text(prj.architectName ?? 'No Architect', style: AppTextStyles.bodyBold.copyWith(color: AppColors.purple, decoration: TextDecoration.underline)),
                          )
                        else
                          Text('No Architect Linked', style: AppTextStyles.bodyBold),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow('Start Date', Formatters.formatDate(prj.startDate)),
                    _buildInfoRow('Expected Handover', prj.expectedCompletionDate != null ? Formatters.formatDate(prj.expectedCompletionDate!) : 'N/A'),
                    _buildInfoRow('Scope Notes', prj.notes ?? 'Standard luminaire design and execution scope'),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadius.lgBorderRadius,
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Financial & Costing Summary', style: AppTextStyles.h3),
                    const Divider(height: 24),
                    _buildInfoRow('Gross Sales Invoiced', Formatters.formatCurrency(totalSalesInvoiced)),
                    _buildInfoRow('Direct Material Purchases', Formatters.formatCurrency(totalProjectPurchases)),
                    _buildInfoRow('Operational Expenses', Formatters.formatCurrency(totalProjectExpenses)),
                    _buildInfoRow('Pending Receivables', Formatters.formatCurrency(totalSalesPending)),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Estimated Project Margin:', style: AppTextStyles.bodyBold),
                        Text(
                          Formatters.formatCurrency(estimatedMargin),
                          style: AppTextStyles.h2.copyWith(
                            color: estimatedMargin >= 0 ? AppColors.successText : AppColors.dangerText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: estimatedMargin >= 0 ? AppColors.primary.withValues(alpha: 0.08) : Colors.red.withValues(alpha: 0.08),
                        borderRadius: AppRadius.smBorderRadius,
                        border: Border.all(color: estimatedMargin >= 0 ? AppColors.primary.withValues(alpha: 0.3) : Colors.red.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Profitability Status:', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                          Text(
                            estimatedMargin >= 0 ? 'PROFITABLE' : 'BUDGET DEFICIT',
                            style: AppTextStyles.bodyBold.copyWith(
                              color: estimatedMargin >= 0 ? AppColors.primary : AppColors.dangerText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Sales & Invoices History
        Text('Sales & Invoices History', style: AppTextStyles.h2),
        const SizedBox(height: 12),
        if (sortedSales.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: AppRadius.mdBorderRadius, border: Border.all(color: AppColors.border)),
            child: Text('No sales documents linked to this project yet.', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
          )
        else
          ErpDataTable(
            columns: const [
              ErpColumn(title: 'Invoice Number'),
              ErpColumn(title: 'Date'),
              ErpColumn(title: 'Document Type'),
              ErpColumn(title: 'Total Invoiced', isNumeric: true),
              ErpColumn(title: 'Outstanding Due', isNumeric: true),
              ErpColumn(title: 'Status'),
              ErpColumn(title: 'Actions'),
            ],
            rows: sortedSales.map((s) {
              return [
                InkWell(
                  onTap: () => ref.read(activeRecordDetailsStackProvider.notifier).push(s.id, 'invoice', details.parentSection),
                  child: Text(s.invoiceNumber, style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary)),
                ),
                Text(Formatters.formatDate(s.saleDate), style: AppTextStyles.bodySmall),
                Text(s.documentType.toString().split('.').last.toUpperCase(), style: AppTextStyles.bodySmall),
                Text(Formatters.formatCurrency(s.totalAmount), style: AppTextStyles.bodyBold),
                Text(
                  Formatters.formatCurrency(s.pendingAmount),
                  style: AppTextStyles.bodyBold.copyWith(color: s.pendingAmount > 0 ? AppColors.dangerText : AppColors.textMuted),
                ),
                ErpStatusBadge.neutral(s.statusLabel.toUpperCase()),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.share, color: Colors.teal, size: 16),
                      tooltip: 'Share Document',
                      onPressed: () => ShareDocumentDialog.show(context, s),
                    ),
                    IconButton(
                      icon: const Icon(Icons.picture_as_pdf, color: AppColors.primary, size: 16),
                      tooltip: 'View PDF',
                      onPressed: () => SalesPdfGeneratorDialog.show(context, s, db),
                    ),
                  ],
                ),
              ];
            }).toList(),
          ),

        // Direct Purchases Linked to Project
        if (projectPurchases.isNotEmpty) ...[
          const SizedBox(height: 28),
          Text('Direct Purchases Linked to Project', style: AppTextStyles.h2),
          const SizedBox(height: 12),
          ErpDataTable(
            columns: const [
              ErpColumn(title: 'PO Number'),
              ErpColumn(title: 'Date'),
              ErpColumn(title: 'Vendor'),
              ErpColumn(title: 'Total (₹)', isNumeric: true),
              ErpColumn(title: 'Paid (₹)', isNumeric: true),
              ErpColumn(title: 'Pending (₹)', isNumeric: true),
              ErpColumn(title: 'Status'),
            ],
            rows: projectPurchases.map((p) {
              return [
                InkWell(
                  onTap: () => ref.read(activeRecordDetailsStackProvider.notifier).push(p.id, 'purchase', details.parentSection),
                  child: Text(p.purchaseNumber, style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary)),
                ),
                Text(Formatters.formatDate(p.purchaseDate), style: AppTextStyles.bodySmall),
                Text(p.vendorName, style: AppTextStyles.bodyMedium),
                Text(Formatters.formatCurrency(p.totalAmount), style: AppTextStyles.bodyBold),
                Text(Formatters.formatCurrency(p.paidAmount), style: AppTextStyles.bodySmall.copyWith(color: AppColors.successText)),
                Text(Formatters.formatCurrency(p.pendingAmount), style: AppTextStyles.bodySmall.copyWith(color: p.pendingAmount > 0 ? AppColors.dangerText : AppColors.textMuted)),
                ErpStatusBadge.neutral(p.statusLabel.toUpperCase()),
              ];
            }).toList(),
          ),
        ],

        // Production Orders Linked to Project
        if (projectProductions.isNotEmpty) ...[
          const SizedBox(height: 28),
          Text('Production Orders Linked to Project', style: AppTextStyles.h2),
          const SizedBox(height: 12),
          ErpDataTable(
            columns: const [
              ErpColumn(title: 'Order No'),
              ErpColumn(title: 'Date'),
              ErpColumn(title: 'Target Product'),
              ErpColumn(title: 'Planned Qty'),
              ErpColumn(title: 'Produced Qty'),
              ErpColumn(title: 'Status'),
            ],
            rows: projectProductions.map((po) {
              return [
                InkWell(
                  onTap: () => ref.read(activeRecordDetailsStackProvider.notifier).push(po.id, 'production', details.parentSection),
                  child: Text(po.productionNumber, style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary)),
                ),
                Text(Formatters.formatDate(po.orderDate), style: AppTextStyles.bodySmall),
                Text(po.finishedProductName, style: AppTextStyles.bodyMedium),
                Text('${po.targetQuantity.toInt()} ${po.unit}', style: AppTextStyles.bodyMedium),
                Text('${po.producedQuantity.toInt()} ${po.unit}', style: AppTextStyles.bodyBold.copyWith(color: AppColors.successText)),
                ErpStatusBadge.neutral(po.statusLabel.toUpperCase()),
              ];
            }).toList(),
          ),
        ],

        // Expenses Linked to Project
        if (projectExpenses.isNotEmpty) ...[
          const SizedBox(height: 28),
          Text('Direct Expenses & Overheads', style: AppTextStyles.h2),
          const SizedBox(height: 12),
          ErpDataTable(
            columns: const [
              ErpColumn(title: 'Expense No'),
              ErpColumn(title: 'Date'),
              ErpColumn(title: 'Category'),
              ErpColumn(title: 'Description'),
              ErpColumn(title: 'Payment Mode'),
              ErpColumn(title: 'Amount (₹)', isNumeric: true),
              ErpColumn(title: 'Status'),
            ],
            rows: projectExpenses.map((exp) {
              return [
                Text(exp.expenseNumber, style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary)),
                Text(Formatters.formatDate(exp.expenseDate), style: AppTextStyles.bodySmall),
                Text(exp.categoryName, style: AppTextStyles.bodyMedium),
                Text(exp.description ?? '-', style: AppTextStyles.bodySmall),
                Text(exp.paymentMethod.toUpperCase(), style: AppTextStyles.bodySmall),
                Text(Formatters.formatCurrency(exp.amount), style: AppTextStyles.bodyBold),
                ErpStatusBadge.neutral(exp.paymentStatusLabel.toUpperCase()),
              ];
            }).toList(),
          ),
        ],

        // Payments & Collections Linked to Project
        if (projectPayments.isNotEmpty) ...[
          const SizedBox(height: 28),
          Text('Payment Transactions & Receipts', style: AppTextStyles.h2),
          const SizedBox(height: 12),
          ErpDataTable(
            columns: const [
              ErpColumn(title: 'Payment No'),
              ErpColumn(title: 'Date'),
              ErpColumn(title: 'Party'),
              ErpColumn(title: 'Reference Doc'),
              ErpColumn(title: 'Amount (₹)', isNumeric: true),
              ErpColumn(title: 'Settlement'),
              ErpColumn(title: 'Mode'),
            ],
            rows: projectPayments.map((pay) {
              return [
                Text(pay.paymentNumber, style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary)),
                Text(Formatters.formatDate(pay.paymentDate), style: AppTextStyles.bodySmall),
                Text(pay.partyName, style: AppTextStyles.bodyMedium),
                Text(pay.referenceDocumentNumber ?? '-', style: AppTextStyles.bodySmall),
                Text(Formatters.formatCurrency(pay.amount), style: AppTextStyles.bodyBold.copyWith(color: AppColors.successText)),
                pay.isFullPayment ? ErpStatusBadge.success('FULL') : ErpStatusBadge.warning('PARTIAL'),
                Text(pay.paymentMode.name.toUpperCase(), style: AppTextStyles.bodySmall),
              ];
            }).toList(),
          ),
        ],

        // Raw Material Consumption Breakdown
        if (rawMaterialConsumption.isNotEmpty) ...[
          const SizedBox(height: 28),
          Text('Raw Material Consumption Breakdown', style: AppTextStyles.h2),
          const SizedBox(height: 12),
          ErpDataTable(
            columns: const [
              ErpColumn(title: 'Item Code'),
              ErpColumn(title: 'Raw Material Name'),
              ErpColumn(title: 'Quantity Consumed'),
              ErpColumn(title: 'Total Material Cost (₹)', isNumeric: true),
            ],
            rows: rawMaterialConsumption.values.map((rm) {
              return [
                Text(rm['code'] as String, style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary)),
                Text(rm['name'] as String, style: AppTextStyles.bodyMedium),
                Text('${(rm['quantity'] as double).toStringAsFixed(1)} ${rm['unit']}', style: AppTextStyles.bodyMedium),
                Text(Formatters.formatCurrency(rm['totalCost'] as double), style: AppTextStyles.bodyBold),
              ];
            }).toList(),
          ),
        ],

        // Finished Product Usage Breakdown
        if (finishedProductUsage.isNotEmpty) ...[
          const SizedBox(height: 28),
          Text('Finished Product Usage Breakdown', style: AppTextStyles.h2),
          const SizedBox(height: 12),
          ErpDataTable(
            columns: const [
              ErpColumn(title: 'SKU Code'),
              ErpColumn(title: 'Finished Product Name'),
              ErpColumn(title: 'Quantity Used / Invoiced'),
              ErpColumn(title: 'Total Line Valuation (₹)', isNumeric: true),
            ],
            rows: finishedProductUsage.values.map((fp) {
              return [
                Text(fp['code'] as String, style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary)),
                Text(fp['name'] as String, style: AppTextStyles.bodyMedium),
                Text('${(fp['quantity'] as double).toInt()} ${fp['unit']}', style: AppTextStyles.bodyMedium),
                Text(Formatters.formatCurrency(fp['totalValue'] as double), style: AppTextStyles.bodyBold),
              ];
            }).toList(),
          ),
        ],

        // Stock Movement Ledger
        if (projectMovements.isNotEmpty) ...[
          const SizedBox(height: 28),
          Text('Stock Movement & Inward/Outward Ledger', style: AppTextStyles.h2),
          const SizedBox(height: 12),
          ErpDataTable(
            columns: const [
              ErpColumn(title: 'Movement ID'),
              ErpColumn(title: 'Date'),
              ErpColumn(title: 'Item Description'),
              ErpColumn(title: 'Transaction Type'),
              ErpColumn(title: 'Source / Inward'),
              ErpColumn(title: 'Quantity Change', isNumeric: true),
            ],
            rows: projectMovements.take(10).map((m) {
              return [
                Text(m.id, style: AppTextStyles.bodySmall),
                Text(Formatters.formatDate(m.timestamp), style: AppTextStyles.bodySmall),
                Text(m.itemName, style: AppTextStyles.bodyMedium),
                Text(m.transactionTypeLabel, style: AppTextStyles.bodySmall),
                Text(m.sourceLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal)),
                Text('${m.quantityChanged > 0 ? "+" : ""}${m.quantityChanged.toInt()} ${m.unit}',
                    style: AppTextStyles.bodyBold.copyWith(
                      color: m.quantityChanged > 0 ? AppColors.successText : AppColors.dangerText,
                    )),
              ];
            }).toList(),
          ),
        ],

        // Activity Timeline (Commented out per request)
        /*
        const SizedBox(height: 28),
        Text('Project Activity Timeline & Audit Trail', style: AppTextStyles.h2),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.lgBorderRadius,
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              _buildTimelineEvent('Project Created', 'Project initiated in master database', Formatters.formatDate(prj.startDate), Icons.flag, Colors.blue),
              if (projectProductions.isNotEmpty)
                _buildTimelineEvent('Production Initiated', '${projectProductions.length} production orders scheduled & materials allocated', Formatters.formatDate(projectProductions.first.orderDate), Icons.precision_manufacturing, Colors.orange),
              if (projectPurchases.isNotEmpty)
                _buildTimelineEvent('Purchases Processed', '${projectPurchases.length} Purchase orders issued for project materials', Formatters.formatDate(projectPurchases.first.purchaseDate), Icons.shopping_bag, Colors.purple),
              if (projectSales.isNotEmpty)
                _buildTimelineEvent('Commercial Invoices Issued', '${projectSales.length} Quotations/Invoices generated with client', Formatters.formatDate(projectSales.first.saleDate), Icons.receipt_long, Colors.green),
              _buildTimelineEvent('Current Status: ${prj.statusLabel.toUpperCase()}', 'Project is actively being tracked across manufacturing, billing and logistics', Formatters.formatDate(DateTime.now()), Icons.check_circle, Colors.teal),
            ],
          ),
        ),
        */
      ],
    );
  }

  /*
  Widget _buildTimelineEvent(String title, String desc, String date, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title, style: AppTextStyles.bodyBold),
                    Text(date, style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(desc, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
  */


  void _showApproveReturnDialog(BuildContext context, Sale s, MockDatabaseService db) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.success.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.check_circle_outline, color: AppColors.success, size: 22),
            ),
            const SizedBox(width: 12),
            const Text('Approve Sales Return & Execute', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Are you sure you want to approve Sales Return ${s.invoiceNumber}?', style: AppTextStyles.bodyMedium),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Automated System Adjustments upon Approval:', style: AppTextStyles.bodyBold.copyWith(fontSize: 12)),
                    const SizedBox(height: 6),
                    Text('• Resalable items will be restocked to Finished Goods inventory.', style: AppTextStyles.bodySmall),
                    Text('• Damaged/Scrap items will be recorded in Stock Adjustments.', style: AppTextStyles.bodySmall),
                    Text('• Original Invoice returned quantities will be updated.', style: AppTextStyles.bodySmall),
                    Text('• Customer balance will be credited / reduced.', style: AppTextStyles.bodySmall),
                    Text('• Architect commission & project revenues will be adjusted.', style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text('Total Credit Note Value: ${Formatters.formatCurrency(s.totalAmount)}', style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            onPressed: () {
              Navigator.of(ctx).pop();
              db.approveSalesReturn(s.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Sales Return ${s.invoiceNumber} Approved! All stock and ledger adjustments executed.'), backgroundColor: AppColors.success),
              );
            },
            child: const Text('Confirm & Execute', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showRejectReturnDialog(BuildContext context, Sale s, MockDatabaseService db) {
    final reasonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.danger.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.cancel_outlined, color: AppColors.danger, size: 22),
            ),
            const SizedBox(width: 12),
            const Text('Reject Sales Return', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: 450,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Provide rejection reason for return ${s.invoiceNumber}:', style: AppTextStyles.bodySmall),
              const SizedBox(height: 12),
              TextFormField(
                controller: reasonCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Enter rejection reason (e.g. Items out of return policy, unauthorized tampering)...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              if (reasonCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a rejection reason.'), backgroundColor: AppColors.warning),
                );
                return;
              }
              Navigator.of(ctx).pop();
              db.rejectSalesReturn(s.id, reasonCtrl.text.trim());
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Sales Return ${s.invoiceNumber} Rejected.'), backgroundColor: AppColors.danger),
              );
            },
            child: const Text('Confirm Rejection', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showProcessRefundDialog(BuildContext context, Sale s, MockDatabaseService db) {
    final refundAmount = s.refundAmount > 0 ? s.refundAmount : s.totalAmount;
    final amountCtrl = TextEditingController(text: refundAmount.toStringAsFixed(0));
    final refCtrl = TextEditingController();
    PaymentMode selectedMode = PaymentMode.creditNote;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.currency_rupee, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              const Text('Disburse Refund / Issue Credit Note', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Settlement for Return: ${s.invoiceNumber} (${s.partyName})', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
                const SizedBox(height: 14),
                DropdownButtonFormField<PaymentMode>(
                  value: selectedMode,
                  decoration: const InputDecoration(labelText: 'Refund / Settlement Channel *'),
                  items: const [
                    DropdownMenuItem(value: PaymentMode.creditNote, child: Text('CUSTOMER STORE CREDIT NOTE (WALLET)')),
                    DropdownMenuItem(value: PaymentMode.bankTransfer, child: Text('BANK TRANSFER / NEFT / RTGS')),
                    DropdownMenuItem(value: PaymentMode.upi, child: Text('UPI / ONLINE REFUND')),
                    DropdownMenuItem(value: PaymentMode.cash, child: Text('CASH REFUND')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedMode = val);
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Refund Amount (₹) *'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: refCtrl,
                  decoration: InputDecoration(
                    labelText: selectedMode == PaymentMode.creditNote ? 'Credit Note Memo / Voucher Ref' : 'Transaction Ref / UTR / Cheque No.',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () {
                final amt = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                if (amt <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid refund amount.'), backgroundColor: AppColors.warning),
                  );
                  return;
                }
                Navigator.of(ctx).pop();
                db.processSalesReturnRefund(
                  returnId: s.id,
                  amount: amt,
                  paymentMode: selectedMode,
                  transactionRef: refCtrl.text.trim().isNotEmpty ? refCtrl.text.trim() : null,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Refund of ${Formatters.formatCurrency(amt)} recorded via ${selectedMode.name.toUpperCase()}!'), backgroundColor: AppColors.success),
                );
              },
              child: const Text('Disburse & Finalize', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // -----------------------------------------------------------------
  // 9. Sales Return Dedicated Details View (5 Key Sections)
  // -----------------------------------------------------------------
  Widget _buildSalesReturnDetails(BuildContext context, WidgetRef ref, Sale s, MockDatabaseService db) {
    // Linked Stock Movements
    final linkedMovements = db.stockMovements.where((m) => s.linkedStockMovementIds.contains(m.id)).toList();
    // Linked Stock Adjustments
    final linkedAdjustments = db.stockAdjustments.where((a) => s.linkedStockAdjustmentIds.contains(a.id)).toList();
    // Linked Refund Payment
    final linkedPayment = s.linkedRefundPaymentId != null ? db.payments.where((p) => p.id == s.linkedRefundPaymentId).firstOrNull : null;
    // Original Invoice
    final origInvoice = s.originalInvoiceId != null ? db.sales.where((inv) => inv.id == s.originalInvoiceId).firstOrNull : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Flow Trail
        _buildDocumentFlowTrail(context, ref, s, db),
        const SizedBox(height: 16),

        // SECTION 1 & 4: Top Cards
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 1: Return Header Information
            Expanded(
              flex: 3,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadius.lgBorderRadius,
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Return Header Information', style: AppTextStyles.h3),
                        ErpStatusBadge.neutral(s.salesReturnStatusLabel.toUpperCase()),
                      ],
                    ),
                    const Divider(height: 24),
                    _buildInfoRow('Return Voucher No', s.invoiceNumber),
                    _buildInfoRow('Return Initiation Date', Formatters.formatDate(s.saleDate)),
                    _buildInfoRow('Customer / Party', s.partyName),
                    _buildInfoRow('Return Type', s.returnType == ReturnType.fullReturn ? 'FULL INVOICE RETURN' : 'PARTIAL ITEM RETURN'),
                    _buildInfoRow('Return Reason', s.returnReason ?? 'Customer Return / Quality'),
                    _buildInfoRow('Inspection & QA Notes', s.qaNotes ?? 'Pending QA clearance'),
                    _buildInfoRow('Created By Operator', s.createdBy ?? 'Admin Staff'),
                    _buildInfoRow('Financial Resolution', s.returnFinancialAction == ReturnFinancialAction.creditNote ? 'Store Credit Note Issued' : 'Direct Refund / Outstanding Adjusted'),
                    if (s.notes != null && s.notes!.isNotEmpty)
                      _buildInfoRow('Auditor Remarks', s.notes!),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Section 4: Financial Summary & Refund Settlement
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadius.lgBorderRadius,
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Financial & Refund Settlement', style: AppTextStyles.h3),
                    const Divider(height: 24),
                    _buildInfoRow('Return Subtotal', Formatters.formatCurrency(s.subtotalAmount)),
                    _buildInfoRow('Discounts Reversed', Formatters.formatCurrency(s.discountAmount)),
                    _buildInfoRow('GST Output Tax Reversal', Formatters.formatCurrency(s.gstAmount)),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Credit Note Value:', style: AppTextStyles.bodyBold),
                        Text(Formatters.formatCurrency(s.totalAmount), style: AppTextStyles.h2.copyWith(color: AppColors.dangerText)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Refund Status:', style: AppTextStyles.bodyMedium),
                        Text(s.refundStatusLabel.toUpperCase(), style: AppTextStyles.bodyBold.copyWith(color: s.refundStatus == RefundStatus.processed ? AppColors.successText : (s.refundStatus == RefundStatus.notRequired ? AppColors.textMuted : AppColors.warningText))),
                      ],
                    ),
                    if (s.refundAmount > 0) ...[
                      const SizedBox(height: 8),
                      _buildInfoRow('Refund Amount Disbursed', Formatters.formatCurrency(s.refundAmount)),
                      if (s.refundPaymentMode != null)
                        _buildInfoRow('Refund Channel', s.refundPaymentMode!.name.toUpperCase()),
                      if (s.refundTransactionRef != null)
                        _buildInfoRow('Transaction / UTR Ref', s.refundTransactionRef!),
                    ],
                    const Divider(height: 24),

                    // Return Action Buttons
                    Text('Workflow Actions', style: AppTextStyles.bodyBold.copyWith(fontSize: 12)),
                    const SizedBox(height: 10),

                    if (s.salesReturnStatus == SalesReturnStatus.draft) ...[
                      ErpButton(
                        text: 'Submit for Warehouse Receiving',
                        icon: Icons.send_outlined,
                        onPressed: () {
                          db.updateSalesReturnStatus(s.id, SalesReturnStatus.submitted);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Return Submitted for Warehouse Receiving'), backgroundColor: AppColors.primary),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                    ],

                    if (s.salesReturnStatus == SalesReturnStatus.submitted) ...[
                      ErpButton(
                        text: 'Acknowledge Items Received',
                        icon: Icons.inventory_2_outlined,
                        onPressed: () {
                          db.updateSalesReturnStatus(s.id, SalesReturnStatus.itemsReceived);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Items Received at Warehouse! Ready for QA.'), backgroundColor: AppColors.primary),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                    ],

                    if (s.salesReturnStatus == SalesReturnStatus.itemsReceived) ...[
                      ErpButton(
                        text: 'Mark QA Inspection Complete',
                        icon: Icons.fact_check_outlined,
                        onPressed: () {
                          db.updateSalesReturnStatus(s.id, SalesReturnStatus.inspection);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('QA Inspection Logged. Ready for Approval.'), backgroundColor: AppColors.primary),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                    ],

                    if (s.salesReturnStatus == SalesReturnStatus.inspection || s.salesReturnStatus == SalesReturnStatus.submitted || s.salesReturnStatus == SalesReturnStatus.itemsReceived || s.salesReturnStatus == SalesReturnStatus.requested) ...[
                      Row(
                        children: [
                          Expanded(
                            child: ErpButton(
                              text: 'Approve & Execute',
                              icon: Icons.check_circle_outline,
                              onPressed: () => _showApproveReturnDialog(context, s, db),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ErpButton(
                              text: 'Reject Return',
                              icon: Icons.cancel_outlined,
                              isOutlined: true,
                              onPressed: () => _showRejectReturnDialog(context, s, db),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],

                    if (s.salesReturnStatus == SalesReturnStatus.approved && (s.refundStatus == RefundStatus.pending || s.refundStatus == RefundStatus.approved)) ...[
                      Row(
                        children: [
                          Expanded(
                            child: ErpButton(
                              text: 'Process Refund / Credit Note',
                              icon: Icons.payments_outlined,
                              onPressed: () => _showProcessRefundDialog(context, s, db),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],

                    // PDF Button
                    Row(
                      children: [
                        Expanded(
                          child: ErpButton(
                            text: 'View / Download Credit Note PDF',
                            isOutlined: true,
                            icon: Icons.picture_as_pdf,
                            onPressed: () => SalesPdfGeneratorDialog.show(context, s, db),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // SECTION 2: Original Transaction Reference Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.lgBorderRadius,
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Original Sales Transaction Reference', style: AppTextStyles.h3),
              const Divider(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('Original Tax Invoice: ', style: AppTextStyles.bodyMedium),
                            if (s.originalInvoiceId != null)
                              InkWell(
                                onTap: () => ref.read(activeRecordDetailsStackProvider.notifier).push(s.originalInvoiceId!, 'invoice', details.parentSection),
                                child: Text(s.originalInvoiceNumber ?? s.originalInvoiceId!, style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary, decoration: TextDecoration.underline)),
                              )
                            else
                              Text(s.originalInvoiceNumber ?? '-', style: AppTextStyles.bodyBold),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildInfoRow('Original Sale Date', origInvoice != null ? Formatters.formatDate(origInvoice.saleDate) : '-'),
                        _buildInfoRow('Invoice Status', origInvoice?.statusLabel ?? '-'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow('Original Invoice Amount', origInvoice != null ? Formatters.formatCurrency(origInvoice.totalAmount) : '-'),
                        _buildInfoRow('Customer Paid Amount', origInvoice != null ? Formatters.formatCurrency(origInvoice.paidAmount) : '-'),
                        _buildInfoRow('Outstanding Pending Balance', origInvoice != null ? Formatters.formatCurrency(origInvoice.pendingAmount) : '-'),
                      ],
                    ),
                  ),
                  if (s.projectName != null || s.salesOrderNumber != null) ...[
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (s.salesOrderNumber != null)
                            _buildInfoRow('Sales Order Ref', s.salesOrderNumber!),
                          if (s.projectName != null)
                            _buildInfoRow('Project Linked', s.projectName!),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // SECTION 3: Returned Items & Condition Breakdown
        Text('Returned Items & Quality Inspection', style: AppTextStyles.h2),
        const SizedBox(height: 12),
        ErpDataTable(
          columns: const [
            ErpColumn(title: 'SKU / Code'),
            ErpColumn(title: 'Product Name'),
            ErpColumn(title: 'Invoiced Qty', isNumeric: true),
            ErpColumn(title: 'Return Qty', isNumeric: true),
            ErpColumn(title: 'Unit Rate', isNumeric: true),
            ErpColumn(title: 'GST %', isNumeric: true),
            ErpColumn(title: 'Condition & Stock Action'),
            ErpColumn(title: 'Restock Status'),
            ErpColumn(title: 'Line Total', isNumeric: true),
          ],
          rows: s.items.map((item) {
            String conditionLabel = 'Resalable (Restock)';
            Color conditionColor = AppColors.successText;
            if (item.returnCondition == ReturnCondition.damaged) {
              conditionLabel = 'Damaged (Damage Stock)';
              conditionColor = AppColors.warningText;
            } else if (item.returnCondition == ReturnCondition.scrap) {
              conditionLabel = 'Scrap (Write-off)';
              conditionColor = AppColors.dangerText;
            }

            final isProcessed = s.isProcessed || s.salesReturnStatus == SalesReturnStatus.approved;
            final stockStatus = isProcessed
                ? (item.returnCondition == ReturnCondition.resalable ? 'Restocked to FG' : 'Adjusted as Loss')
                : 'Pending Approval';

            return [
              InkWell(
                onTap: () => ref.read(activeRecordDetailsStackProvider.notifier).push(item.finishedProductId, 'finishedProduct', details.parentSection),
                child: Text(item.finishedProductCode, style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary)),
              ),
              Text(item.finishedProductName, style: AppTextStyles.bodyMedium),
              Text('${item.invoicedQuantity.toInt()} ${item.unit}', style: AppTextStyles.bodySmall),
              Text('${item.quantity.toInt()} ${item.unit}', style: AppTextStyles.bodyBold),
              Text(Formatters.formatCurrency(item.rate), style: AppTextStyles.bodySmall),
              Text('${item.gstPercent.toInt()}%', style: AppTextStyles.bodySmall),
              Text(conditionLabel, style: AppTextStyles.bodyBold.copyWith(color: conditionColor)),
              Text(stockStatus, style: AppTextStyles.bodySmall.copyWith(color: isProcessed ? AppColors.successText : AppColors.textMuted)),
              Text(Formatters.formatCurrency(item.lineTotal), style: AppTextStyles.bodyBold),
            ];
          }).toList(),
        ),

        // SECTION 5: Related Transactions Audit Trail
        const SizedBox(height: 28),
        Text('Related Transactions Audit Trail', style: AppTextStyles.h2),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.lgBorderRadius,
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (origInvoice != null) ...[
                    ActionChip(
                      avatar: const Icon(Icons.receipt_long, size: 14, color: Colors.white),
                      label: Text('Original Invoice: ${origInvoice.invoiceNumber}', style: const TextStyle(fontSize: 11, color: Colors.white)),
                      backgroundColor: AppColors.primary,
                      onPressed: () => ref.read(activeRecordDetailsStackProvider.notifier).push(origInvoice.id, 'invoice', details.parentSection),
                    ),
                  ],
                  if (linkedMovements.isNotEmpty) ...[
                    ...linkedMovements.map((m) => Chip(
                          avatar: const Icon(Icons.swap_horiz, size: 14, color: Colors.white),
                          label: Text('Stock In Movement: ${m.id}', style: const TextStyle(fontSize: 11, color: Colors.white)),
                          backgroundColor: AppColors.success,
                        )),
                  ],
                  if (linkedAdjustments.isNotEmpty) ...[
                    ...linkedAdjustments.map((a) => Chip(
                          avatar: const Icon(Icons.tune, size: 14, color: Colors.white),
                          label: Text('Stock Adjustment: ${a.adjustmentNumber} (${a.reasonLabel})', style: const TextStyle(fontSize: 11, color: Colors.white)),
                          backgroundColor: AppColors.warning,
                        )),
                  ],
                  if (linkedPayment != null) ...[
                    ActionChip(
                      avatar: const Icon(Icons.payments, size: 14, color: Colors.white),
                      label: Text('Refund Voucher: ${linkedPayment.paymentNumber}', style: const TextStyle(fontSize: 11, color: Colors.white)),
                      backgroundColor: AppColors.purple,
                      onPressed: () => ref.read(activeRecordDetailsStackProvider.notifier).push(linkedPayment.id, 'payment', details.parentSection),
                    ),
                  ],
                  if (s.salesReturnStatus == SalesReturnStatus.approved && linkedMovements.isEmpty && linkedAdjustments.isEmpty && linkedPayment == null)
                    Text('Direct ledger adjustment recorded on approval.', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
                ],
              ),
            ],
          ),
        ),

        // Activity Timeline
        if (s.activityLogs.isNotEmpty) ...[
          const SizedBox(height: 28),
          Text('Return Activity & Audit History', style: AppTextStyles.h2),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.lgBorderRadius,
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: s.activityLogs.map((log) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.history, size: 16, color: AppColors.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(log.action, style: AppTextStyles.bodyBold),
                                Text(Formatters.formatDateTime(log.timestamp), style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
                              ],
                            ),
                            if (log.details != null)
                              Text(log.details!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                            Text('By: ${log.performedBy}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted, fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }

  // -----------------------------------------------------------------
  // 9b. Regular Sales Documents (Invoice, Quotation, Order, Delivery)
  // -----------------------------------------------------------------
  Widget _buildSaleDetails(BuildContext context, WidgetRef ref, Sale s, MockDatabaseService db) {
    final payHistory = db.payments.where((p) => p.referenceDocumentId == s.id || (s.linkedPaymentIds.contains(p.id))).toList();
    final linkedReturns = db.salesReturns.where((r) => r.originalInvoiceId == s.id).toList();
    final approvedReturnsTotal = linkedReturns.where((r) => r.salesReturnStatus == SalesReturnStatus.approved).fold(0.0, (sum, r) => sum + r.totalAmount);
    final netSaleAmount = (s.totalAmount - approvedReturnsTotal).clamp(0.0, double.infinity);

    // Fetch customer details
    String customerCode = '-';
    String customerEmail = '-';
    String customerPhone = '-';
    String billingAddress = '-';
    String shippingAddress = '-';

    if (s.partyType == PartyType.customer) {
      final cust = db.customers.where((c) => c.id == s.partyId).firstOrNull ?? (db.customers.isNotEmpty ? db.customers.first : null);
      if (cust != null) {
        customerCode = cust.id;
        customerEmail = cust.email;
        customerPhone = cust.mobile;
        billingAddress = cust.address;
        shippingAddress = cust.address;
      }
    } else {
      final dlr = db.dealers.where((d) => d.id == s.partyId).firstOrNull ?? (db.dealers.isNotEmpty ? db.dealers.first : null);
      if (dlr != null) {
        customerCode = dlr.id;
        customerEmail = dlr.email;
        customerPhone = dlr.mobile;
        billingAddress = dlr.address;
        shippingAddress = dlr.address;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Linked Document Flow Trail
        _buildDocumentFlowTrail(context, ref, s, db),
        const SizedBox(height: 16),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Card: Main details
            Expanded(
              flex: 3,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadius.lgBorderRadius,
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Document Header Information', style: AppTextStyles.h3),
                    const Divider(height: 24),
                    _buildInfoRow('Document Reference ID', s.invoiceNumber),
                    _buildInfoRow('Document Type', s.documentType.toString().split('.').last.toUpperCase()),
                    _buildInfoRow('Client Party Name', s.partyName),
                    _buildInfoRow('Client Code', customerCode),
                    _buildInfoRow('Contact Phone', customerPhone),
                    _buildInfoRow('Contact Email', customerEmail),
                    _buildInfoRow('Billing Address', billingAddress),
                    _buildInfoRow('Shipping Address', shippingAddress),
                    
                    if (s.projectName != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Linked Project Name:', style: AppTextStyles.bodyMedium),
                          if (s.projectId != null)
                            InkWell(
                              onTap: () => ref.read(activeRecordDetailsStackProvider.notifier).push(s.projectId!, 'project', details.parentSection),
                              child: Text(s.projectName ?? '', style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary, decoration: TextDecoration.underline)),
                            )
                          else
                            Text(s.projectName ?? '', style: AppTextStyles.bodyBold),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    _buildInfoRow('Workflow Issue Date', Formatters.formatDate(s.saleDate)),
                    
                    if (s.documentType == SalesDocumentType.quotation && s.validUntil != null)
                      _buildInfoRow('Validity Valid Until', Formatters.formatDate(s.validUntil!)),
                    if (s.documentType == SalesDocumentType.salesOrder && s.deliveryDate != null)
                      _buildInfoRow('Expected Delivery Date', Formatters.formatDate(s.deliveryDate!)),
                    if (s.documentType == SalesDocumentType.delivery) ...[
                      _buildInfoRow('Vehicle Registration', s.vehicleNumber ?? 'Not Assigned'),
                      _buildInfoRow('Driver Contact', s.driverContact ?? 'Direct Dispatch'),
                      _buildInfoRow('LR / Tracking Number', s.trackingNumber ?? 'Pending'),
                    ],

                    if (s.documentType == SalesDocumentType.invoice) ...[
                      _buildInfoRow('Return Status Indicator', s.invoiceReturnStatusLabel),
                    ],

                    _buildInfoRow('Payment Terms Remarks', 'Net 30 Days'),
                    _buildInfoRow('Delivery Terms Remarks', 'Ex-Works / Local Transport'),
                    _buildInfoRow('Notes / Terms & Conditions', s.notes ?? '-'),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Right Card: Action summary and totals
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadius.lgBorderRadius,
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Financials & Actions', style: AppTextStyles.h3),
                    const Divider(height: 24),
                    _buildInfoRow('Subtotal Amount', Formatters.formatCurrency(s.subtotalAmount)),
                    _buildInfoRow('Discounts Amount', Formatters.formatCurrency(s.discountAmount)),
                    _buildInfoRow('GST Output Tax', Formatters.formatCurrency(s.gstAmount)),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Grand Total Invoiced:', style: AppTextStyles.bodyBold),
                        Text(Formatters.formatCurrency(s.totalAmount), style: AppTextStyles.h2.copyWith(color: AppColors.primary)),
                      ],
                    ),
                    if (approvedReturnsTotal > 0) ...[
                      const SizedBox(height: 6),
                      _buildInfoRow('Total Sales Returns', '- ${Formatters.formatCurrency(approvedReturnsTotal)}'),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Net Invoice Revenue:', style: AppTextStyles.bodyBold),
                          Text(Formatters.formatCurrency(netSaleAmount), style: AppTextStyles.bodyBold.copyWith(color: AppColors.successText)),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    _buildInfoRow('Amount Received / Paid', Formatters.formatCurrency(s.paidAmount)),
                    _buildInfoRow('Outstanding Balance', Formatters.formatCurrency(s.pendingAmount)),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Current Status:', style: AppTextStyles.bodyBold),
                        Text(s.statusLabel.toUpperCase(), style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary)),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Quotation actions
                    if (s.documentType == SalesDocumentType.quotation) ...[
                      if (s.quotationStatus == QuotationStatus.draft ||
                          s.quotationStatus == QuotationStatus.sent ||
                          s.quotationStatus == QuotationStatus.accepted ||
                          s.quotationStatus == QuotationStatus.approved ||
                          s.quotationStatus == null) ...[
                        if (s.quotationStatus == QuotationStatus.draft || s.quotationStatus == QuotationStatus.sent || s.quotationStatus == null) ...[
                          Row(
                            children: [
                              Expanded(
                                child: ErpButton(
                                  text: 'Accept Quotation',
                                  icon: Icons.check_circle_outline,
                                  onPressed: () async {
                                    try {
                                      await db.updateQuotationStatusAsync(s.id, QuotationStatus.accepted.name);
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Quotation ${s.invoiceNumber} marked as ACCEPTED!'),
                                          backgroundColor: AppColors.success,
                                        ),
                                      );
                                    } catch (e) {
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Failed to accept quotation: $e'), backgroundColor: AppColors.danger),
                                      );
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                        ],
                        Row(
                          children: [
                            Expanded(
                              child: ErpButton(
                                text: 'Generate Proforma Invoice',
                                icon: Icons.receipt_long_outlined,
                                onPressed: () async {
                                  try {
                                    final pi = await db.convertQuotationToProformaAsync(s.id);
                                    if (!context.mounted) return;
                                    ref.read(activeRecordDetailsStackProvider.notifier).push(pi.id, 'proformaInvoice', details.parentSection);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Generated Proforma Invoice ${pi.invoiceNumber} from ${s.invoiceNumber}!'),
                                        backgroundColor: AppColors.success,
                                      ),
                                    );
                                  } catch (e) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Failed to generate proforma: $e'), backgroundColor: AppColors.danger),
                                    );
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: ErpButton(
                                text: 'Create Revision',
                                isOutlined: true,
                                icon: Icons.history_edu,
                                onPressed: () {
                                  ref.read(salesCreateDocTypeProvider.notifier).state = SalesDocumentType.quotation;
                                  ref.read(salesCreateSourceDocIdProvider.notifier).state = s.id;
                                  ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.createQuotation;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (s.quotationStatus == QuotationStatus.converted && s.proformaReferenceId != null) ...[
                        Row(
                          children: [
                            Expanded(
                              child: ErpButton(
                                text: 'View Generated Proforma',
                                icon: Icons.receipt_long,
                                onPressed: () {
                                  ref.read(activeRecordDetailsStackProvider.notifier).push(s.proformaReferenceId!, 'proformaInvoice', details.parentSection);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],

                    // Proforma Actions
                    if (s.documentType == SalesDocumentType.proformaInvoice) ...[
                      Row(
                        children: [
                          Expanded(
                            child: ErpButton(
                              text: 'Record Advance Payment',
                              icon: Icons.payments_outlined,
                              onPressed: () {
                                ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.proformaInvoices;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Sales Order status changer dropdown
                    if (s.documentType == SalesDocumentType.salesOrder) ...[
                      DropdownButtonFormField<SalesOrderStatus>(
                        value: s.salesOrderStatus ?? SalesOrderStatus.pending,
                        decoration: const InputDecoration(labelText: 'Change Order Status'),
                        items: SalesOrderStatus.values.map((status) {
                          return DropdownMenuItem(value: status, child: Text(status.toString().split('.').last.toUpperCase()));
                        }).toList(),
                        onChanged: (newStatus) {
                          if (newStatus != null) {
                            db.updateSalesOrderStatus(s.id, newStatus);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Order Status updated to ${newStatus.toString().split('.').last.toUpperCase()}')),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Invoice actions
                    if (s.documentType == SalesDocumentType.invoice && s.status != SaleStatus.cancelled) ...[
                      if (s.invoiceReturnStatus != InvoiceReturnIndicator.fullyReturned) ...[
                        Row(
                          children: [
                            Expanded(
                              child: ErpButton(
                                text: 'Create Sales Return',
                                isOutlined: true,
                                icon: Icons.assignment_return_outlined,
                                onPressed: () {
                                  ref.read(salesCreateDocTypeProvider.notifier).state = SalesDocumentType.salesReturn;
                                  ref.read(salesCreateSourceDocIdProvider.notifier).state = s.id;
                                  ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.createSalesReturn;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (s.pendingAmount > 0) ...[
                        Row(
                          children: [
                            Expanded(
                              child: ErpButton(
                                text: 'Record Payment',
                                icon: Icons.payments_outlined,
                                onPressed: () {
                                  ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.customerPayments;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],

                    // Delivery Actions
                    if (s.documentType == SalesDocumentType.delivery) ...[
                      Row(
                        children: [
                          Expanded(
                            child: ErpButton(
                              text: 'Generate Tax Invoice',
                              icon: Icons.receipt_long,
                              onPressed: () {
                                final inv = db.createSalesInvoiceFromDelivery(deliveryId: s.id);
                                ref.read(activeRecordDetailsStackProvider.notifier).push(inv.id, 'invoice', details.parentSection);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Tax Invoice ${inv.invoiceNumber} created from delivery!'), backgroundColor: AppColors.success),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Multi-Channel Share & Unified PDF Preview
                    Row(
                      children: [
                        Expanded(
                          child: ErpButton(
                            text: 'Share Document',
                            icon: Icons.share,
                            onPressed: () {
                              ShareDocumentDialog.show(context, s);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ErpButton(
                            text: 'View / PDF',
                            isOutlined: true,
                            icon: Icons.picture_as_pdf,
                            onPressed: () {
                              SalesPdfGeneratorDialog.show(context, s, db);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        Text('Line Items & Fulfillment Tracking', style: AppTextStyles.h2),
        const SizedBox(height: 12),
        ErpDataTable(
          columns: [
            const ErpColumn(title: 'Product SKU'),
            const ErpColumn(title: 'Product Name'),
            const ErpColumn(title: 'Invoiced Qty', isNumeric: true),
            if (s.documentType == SalesDocumentType.invoice) const ErpColumn(title: 'Returned', isNumeric: true),
            const ErpColumn(title: 'Rate', isNumeric: true),
            const ErpColumn(title: 'Discount', isNumeric: true),
            const ErpColumn(title: 'GST Tax', isNumeric: true),
            const ErpColumn(title: 'Line Total', isNumeric: true),
          ],
          rows: s.items.map((item) {
            return [
              InkWell(
                onTap: () => ref.read(activeRecordDetailsStackProvider.notifier).push(item.finishedProductId, 'finishedProduct', details.parentSection),
                child: Text(item.finishedProductCode, style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary)),
              ),
              Text(item.finishedProductName, style: AppTextStyles.bodyMedium),
              Text('${item.quantity.toInt()} ${item.unit}', style: AppTextStyles.bodyBold),
              if (s.documentType == SalesDocumentType.invoice)
                Text('${item.returnedQuantity.toInt()} ${item.unit}', style: AppTextStyles.bodySmall.copyWith(color: item.returnedQuantity > 0 ? AppColors.dangerText : AppColors.textMuted)),
              Text(Formatters.formatCurrency(item.rate), style: AppTextStyles.bodySmall),
              Text(Formatters.formatCurrency(item.discountAmount), style: AppTextStyles.bodySmall),
              Text('${item.gstPercent.toInt()}%', style: AppTextStyles.bodySmall),
              Text(Formatters.formatCurrency(item.lineTotal), style: AppTextStyles.bodyBold),
            ];
          }).toList(),
        ),

        // Document Activity Timeline
        if (s.activityLogs.isNotEmpty) ...[
          const SizedBox(height: 28),
          Text('Document Activity & Audit Timeline', style: AppTextStyles.h2),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.lgBorderRadius,
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: s.activityLogs.map((log) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.history, size: 16, color: AppColors.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(log.action, style: AppTextStyles.bodyBold),
                                Text(Formatters.formatDateTime(log.timestamp), style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
                              ],
                            ),
                            if (log.details != null)
                              Text(log.details!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                            Text('By: ${log.performedBy}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted, fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],

        if (payHistory.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Payments Received against this Record', style: AppTextStyles.h2),
          const SizedBox(height: 12),
          ErpDataTable(
            columns: const [
              ErpColumn(title: 'Payment ID'),
              ErpColumn(title: 'Date'),
              ErpColumn(title: 'Amount Received', isNumeric: true),
              ErpColumn(title: 'Payment Mode'),
              ErpColumn(title: 'Transaction Reference'),
            ],
            rows: payHistory.map((p) {
              return [
                InkWell(
                  onTap: () => ref.read(activeRecordDetailsStackProvider.notifier).push(p.id, 'payment', details.parentSection),
                  child: Text(p.paymentNumber, style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary)),
                ),
                Text(Formatters.formatDate(p.paymentDate), style: AppTextStyles.bodySmall),
                Text(Formatters.formatCurrency(p.amount), style: AppTextStyles.bodyBold.copyWith(color: AppColors.successText)),
                Text(p.paymentMode.toString().split('.').last.toUpperCase(), style: AppTextStyles.bodySmall),
                Text(p.transactionReference ?? '-', style: AppTextStyles.bodySmall),
              ];
            }).toList(),
          ),
        ],

        if (linkedReturns.isNotEmpty) ...[
          const SizedBox(height: 28),
          Text('Sales Returns & Credit Notes Linked to this Invoice', style: AppTextStyles.h2),
          const SizedBox(height: 12),
          ErpDataTable(
            columns: const [
              ErpColumn(title: 'Return No'),
              ErpColumn(title: 'Date'),
              ErpColumn(title: 'Return Type'),
              ErpColumn(title: 'Return Value', isNumeric: true),
              ErpColumn(title: 'Status'),
              ErpColumn(title: 'Refund Status'),
            ],
            rows: linkedReturns.map((r) {
              return [
                InkWell(
                  onTap: () => ref.read(activeRecordDetailsStackProvider.notifier).push(r.id, 'salesReturn', details.parentSection),
                  child: Text(r.invoiceNumber, style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary)),
                ),
                Text(Formatters.formatDate(r.saleDate), style: AppTextStyles.bodySmall),
                Text(r.returnType == ReturnType.fullReturn ? 'Full' : 'Partial', style: AppTextStyles.bodySmall),
                Text(Formatters.formatCurrency(r.totalAmount), style: AppTextStyles.bodyBold),
                Text(r.salesReturnStatusLabel.toUpperCase(), style: AppTextStyles.bodySmall),
                Text(r.refundStatusLabel, style: AppTextStyles.bodySmall),
              ];
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildDocumentFlowTrail(BuildContext context, WidgetRef ref, Sale s, MockDatabaseService db) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdBorderRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text('Document Flow:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textMuted)),
          if (s.parentQuotationNumber != null || s.originalQuotationId != null) ...[
            ActionChip(
              avatar: const Icon(Icons.request_quote, size: 14, color: Colors.white),
              label: Text(s.parentQuotationNumber ?? 'Quotation', style: const TextStyle(fontSize: 11, color: Colors.white)),
              backgroundColor: AppColors.primaryDark,
              onPressed: () {
                final qId = s.parentQuotationId ?? s.originalQuotationId;
                if (qId != null) ref.read(activeRecordDetailsStackProvider.notifier).push(qId, 'quotation', details.parentSection);
              },
            ),
            const Icon(Icons.arrow_forward, size: 14, color: AppColors.textMuted),
          ],
          if (s.proformaNumber != null) ...[
            ActionChip(
              avatar: const Icon(Icons.receipt_outlined, size: 14, color: Colors.white),
              label: Text(s.proformaNumber!, style: const TextStyle(fontSize: 11, color: Colors.white)),
              backgroundColor: AppColors.warning,
              onPressed: () {
                if (s.proformaReferenceId != null) ref.read(activeRecordDetailsStackProvider.notifier).push(s.proformaReferenceId!, 'proformaInvoice', details.parentSection);
              },
            ),
            const Icon(Icons.arrow_forward, size: 14, color: AppColors.textMuted),
          ],
          if (s.salesOrderNumber != null) ...[
            ActionChip(
              avatar: const Icon(Icons.shopping_bag_outlined, size: 14, color: Colors.white),
              label: Text(s.salesOrderNumber!, style: const TextStyle(fontSize: 11, color: Colors.white)),
              backgroundColor: AppColors.info,
              onPressed: () {
                if (s.salesOrderReferenceId != null) ref.read(activeRecordDetailsStackProvider.notifier).push(s.salesOrderReferenceId!, 'salesOrder', details.parentSection);
              },
            ),
            const Icon(Icons.arrow_forward, size: 14, color: AppColors.textMuted),
          ],
          if (s.linkedProductionOrderIds.isNotEmpty) ...[
            ...s.linkedProductionOrderIds.map((pId) {
              final po = db.productionOrders.where((p) => p.id == pId).firstOrNull;
              return ActionChip(
                avatar: const Icon(Icons.precision_manufacturing, size: 14, color: Colors.white),
                label: Text(po?.productionNumber ?? pId, style: const TextStyle(fontSize: 11, color: Colors.white)),
                backgroundColor: AppColors.purple,
                onPressed: () {
                  ref.read(activeRecordDetailsStackProvider.notifier).push(pId, 'production', details.parentSection);
                },
              );
            }),
            const Icon(Icons.arrow_forward, size: 14, color: AppColors.textMuted),
          ],
          if (s.linkedDeliveryIds.isNotEmpty) ...[
            ...s.linkedDeliveryIds.map((dId) {
              final del = db.sales.where((x) => x.id == dId).firstOrNull;
              return ActionChip(
                avatar: const Icon(Icons.local_shipping, size: 14, color: Colors.white),
                label: Text(del?.invoiceNumber ?? dId, style: const TextStyle(fontSize: 11, color: Colors.white)),
                backgroundColor: AppColors.teal,
                onPressed: () {
                  ref.read(activeRecordDetailsStackProvider.notifier).push(dId, 'delivery', details.parentSection);
                },
              );
            }),
            const Icon(Icons.arrow_forward, size: 14, color: AppColors.textMuted),
          ],
          Chip(
            label: Text('${s.documentType.toString().split('.').last.toUpperCase()} (${s.invoiceNumber})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            backgroundColor: AppColors.primaryLight,
          ),
        ],
      ),
    );
  }

  // -----------------------------------------------------------------
  // 10. Payment Details
  // -----------------------------------------------------------------
  Widget _buildPaymentDetails(BuildContext context, WidgetRef ref, ErpPayment pay, MockDatabaseService db) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgBorderRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Payment Voucher Receipt', style: AppTextStyles.h2),
              ErpStatusBadge.success(pay.paymentStatus?.toUpperCase() ?? 'COMPLETED'),
            ],
          ),
          const Divider(height: 32),
          _buildInfoRow('Payment Reference ID', pay.paymentNumber),
          _buildInfoRow('Payment Voucher Date', Formatters.formatDateTime(pay.paymentDate)),
          _buildInfoRow('Transaction Ledger Account', pay.typeLabel),
          _buildInfoRow('Associated Party Name', pay.partyName),
          if (pay.referenceDocumentNumber != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Linked ERP Document Reference:', style: AppTextStyles.bodyMedium),
                InkWell(
                  onTap: () {
                    // Navigate to appropriate detail
                    if (pay.paymentType == PaymentType.vendorPayment) {
                      ref.read(activeRecordDetailsStackProvider.notifier).push(pay.referenceDocumentId ?? '', 'purchase', details.parentSection);
                    } else if (pay.paymentType == PaymentType.customerPayment || pay.paymentType == PaymentType.dealerPayment) {
                      ref.read(activeRecordDetailsStackProvider.notifier).push(pay.referenceDocumentId ?? '', 'invoice', details.parentSection);
                    }
                  },
                  child: Text(pay.referenceDocumentNumber!, style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary, decoration: TextDecoration.underline)),
                ),
              ],
            ),
          const SizedBox(height: 8),
          _buildInfoRow('Payment / Settlement Mode', pay.paymentMode.toString().split('.').last.toUpperCase()),
          _buildInfoRow('UTR / Check / Transaction Ref', pay.transactionReference ?? 'Direct Ledger Entry'),
          _buildInfoRow('Auditor Remarks / Notes', pay.notes ?? '-'),
          const Divider(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Settlement Voucher Total Amount:', style: AppTextStyles.bodyBold.copyWith(fontSize: 16)),
              Text(Formatters.formatCurrency(pay.amount), style: AppTextStyles.h2.copyWith(color: AppColors.successText)),
            ],
          ),
          if (pay.attachmentUrl != null) ...[
            const SizedBox(height: 20),
            Text('Payment Attachment:', style: AppTextStyles.bodyBold),
            const SizedBox(height: 8),
            Container(
              height: 120,
              width: 200,
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: AppRadius.smBorderRadius,
                border: Border.all(color: AppColors.border),
              ),
              child: const Center(
                child: Icon(Icons.picture_as_pdf, size: 40, color: AppColors.danger),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNotFound(BuildContext context, dynamic stack, String entityName) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text('$entityName Not Found', style: AppTextStyles.h2),
          const SizedBox(height: 8),
          Text('The requested record (ID: ${details.recordId}) does not exist in the active database.', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted)),
          const SizedBox(height: 24),
          ErpButton(
            text: 'Go Back',
            icon: Icons.arrow_back,
            onPressed: () => stack.pop(),
          ),
        ],
      ),
    );
  }

  // Common UI builder row helper
  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.bodyMedium),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: valueColor != null ? AppTextStyles.bodyBold.copyWith(color: valueColor) : AppTextStyles.bodyBold,
            ),
          ),
        ],
      ),
    );
  }
}
