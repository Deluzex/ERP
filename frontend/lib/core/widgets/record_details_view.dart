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
import '../../features/sales/widgets/quotation_pdf_preview_dialog.dart';
import '../utils/formatters.dart';
import 'erp_button.dart';
import 'erp_data_table.dart';
import 'erp_status_badge.dart';

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
        final rm = db.rawMaterials.firstWhere((r) => r.id == details.recordId, orElse: () => db.rawMaterials.first);
        title = 'Raw Material Details';
        subtitle = '${rm.name} (${rm.itemCode})';
        detailsWidget = _buildRawMaterialDetails(context, ref, rm, db);
        break;

      case 'vendor':
        final v = db.vendors.firstWhere((ven) => ven.id == details.recordId, orElse: () => db.vendors.first);
        title = 'Vendor Details';
        subtitle = v.name;
        detailsWidget = _buildVendorDetails(context, ref, v, db);
        break;

      case 'purchase':
        final p = db.purchases.firstWhere((pur) => pur.id == details.recordId, orElse: () => db.purchases.first);
        title = 'Purchase Order Details';
        subtitle = p.purchaseNumber;
        detailsWidget = _buildPurchaseDetails(context, ref, p, db);
        break;

      case 'production':
        final po = db.productionOrders.firstWhere((o) => o.id == details.recordId, orElse: () => db.productionOrders.first);
        title = 'Production Order Details';
        subtitle = po.productionNumber;
        detailsWidget = _buildProductionDetails(context, ref, po, db);
        break;

      case 'customer':
        final c = db.customers.firstWhere((cust) => cust.id == details.recordId, orElse: () => db.customers.first);
        title = 'Customer Profile';
        subtitle = c.name;
        detailsWidget = _buildCustomerDetails(context, ref, c, db);
        break;

      case 'dealer':
        final d = db.dealers.firstWhere((dlr) => dlr.id == details.recordId, orElse: () => db.dealers.first);
        title = 'Dealer Profile';
        subtitle = d.name;
        detailsWidget = _buildDealerDetails(context, ref, d, db);
        break;

      case 'architect':
        final a = db.architects.firstWhere((arc) => arc.id == details.recordId, orElse: () => db.architects.first);
        title = 'Architect Profile';
        subtitle = a.name;
        detailsWidget = _buildArchitectDetails(context, ref, a, db);
        break;

      case 'project':
        final prj = db.projects.firstWhere((p) => p.id == details.recordId, orElse: () => db.projects.first);
        title = 'Project Details';
        subtitle = prj.name;
        detailsWidget = _buildProjectDetails(context, ref, prj, db);
        break;

      case 'quotation':
      case 'salesOrder':
      case 'invoice':
      case 'salesReturn':
        final s = db.sales.firstWhere((sale) => sale.id == details.recordId, orElse: () => db.sales.first);
        if (s.documentType == SalesDocumentType.quotation) {
          title = 'Quotation Details';
        } else if (s.documentType == SalesDocumentType.salesOrder) {
          title = 'Sales Order Details';
        } else if (s.documentType == SalesDocumentType.salesReturn) {
          title = 'Sales Return Details';
        } else {
          title = 'Sales Invoice Details';
        }
        subtitle = s.invoiceNumber;
        detailsWidget = _buildSaleDetails(context, ref, s, db);
        break;

      case 'payment':
        final pay = db.payments.firstWhere((py) => py.id == details.recordId, orElse: () => db.payments.first);
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
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.h1),
                  const SizedBox(height: 4),
                  Text(subtitle, style: AppTextStyles.subtitle),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
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
                    Text('Vendor Profile', style: AppTextStyles.h3),
                    const Divider(height: 24),
                    _buildInfoRow('Vendor Code', v.id),
                    _buildInfoRow('Company Name', v.name),
                    _buildInfoRow('Contact Person', v.contactPerson),
                    _buildInfoRow('Mobile / Phone', v.mobile),
                    _buildInfoRow('Email Address', v.email),
                    _buildInfoRow('GST Registration', v.gstNumber),
                    _buildInfoRow('PAN Number', v.panNumber),
                    _buildInfoRow('Factory / Address', v.address),
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
                    Text('Financial Status', style: AppTextStyles.h3),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Outstanding Balance:', style: AppTextStyles.bodyMedium),
                        Text(
                          Formatters.formatCurrency(v.outstandingBalance),
                          style: AppTextStyles.h2.copyWith(color: v.outstandingBalance > 0 ? AppColors.dangerText : AppColors.textPrimary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow('Credit Limit Allowed', Formatters.formatCurrency(v.creditLimit)),
                    _buildInfoRow('Payment Terms', v.paymentTerms),
                    _buildInfoRow('Registered Date', Formatters.formatDate(v.createdAt)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text('Vendor Purchase Orders History', style: AppTextStyles.h2),
        const SizedBox(height: 12),
        ErpDataTable(
          columns: const [
            ErpColumn(title: 'PO Number'),
            ErpColumn(title: 'Purchase Date'),
            ErpColumn(title: 'Linked Invoice'),
            ErpColumn(title: 'Items Count', isNumeric: true),
            ErpColumn(title: 'Total Amount', isNumeric: true),
            ErpColumn(title: 'Pending Due', isNumeric: true),
            ErpColumn(title: 'Status'),
          ],
          rows: vendorPurchases.map((p) {
            return [
              InkWell(
                onTap: () => ref.read(activeRecordDetailsStackProvider.notifier).push(p.id, 'purchase', details.parentSection),
                child: Text(p.purchaseNumber, style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary)),
              ),
              Text(Formatters.formatDate(p.purchaseDate), style: AppTextStyles.bodySmall),
              Text(p.vendorInvoiceNumber, style: AppTextStyles.bodySmall),
              Text('${p.items.length} items', style: AppTextStyles.bodySmall),
              Text(Formatters.formatCurrency(p.totalAmount), style: AppTextStyles.bodyBold),
              Text(
                Formatters.formatCurrency(p.pendingAmount),
                style: AppTextStyles.bodyBold.copyWith(color: p.pendingAmount > 0 ? AppColors.dangerText : AppColors.textMuted),
              ),
              Text(p.statusLabel, style: AppTextStyles.bodySmall),
            ];
          }).toList(),
        ),
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
            ErpColumn(title: 'Discount Amount', isNumeric: true),
            ErpColumn(title: 'GST Tax', isNumeric: true),
            ErpColumn(title: 'Line Total', isNumeric: true),
          ],
          rows: p.items.map((item) {
            return [
              InkWell(
                onTap: () => ref.read(activeRecordDetailsStackProvider.notifier).push(item.rawMaterialId, 'rawMaterial', details.parentSection),
                child: Text(item.rawMaterialCode, style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary)),
              ),
              Text(item.rawMaterialName, style: AppTextStyles.bodyMedium),
              Text('${item.quantity} ${item.unit}', style: AppTextStyles.bodyMedium),
              Text(Formatters.formatCurrency(item.rate), style: AppTextStyles.bodySmall),
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
    final customerSales = db.sales.where((s) => s.partyId == c.id).toList();

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
                    Text('Customer Profile', style: AppTextStyles.h3),
                    const Divider(height: 24),
                    _buildInfoRow('Customer Code', c.id),
                    _buildInfoRow('Client Name', c.name),
                    _buildInfoRow('Contact Number', c.mobile),
                    _buildInfoRow('Email Address', c.email),
                    _buildInfoRow('Registered Address', c.address),
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
                    Text('Outstanding Balance', style: AppTextStyles.h3),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Receivables:', style: AppTextStyles.bodyMedium),
                        Text(
                          Formatters.formatCurrency(c.outstandingAmount),
                          style: AppTextStyles.h2.copyWith(color: c.outstandingAmount > 0 ? AppColors.dangerText : AppColors.successText),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow('Created Date', Formatters.formatDate(c.createdAt)),
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
      ],
    );
  }

  // -----------------------------------------------------------------
  // 6. Dealer Details
  // -----------------------------------------------------------------
  Widget _buildDealerDetails(BuildContext context, WidgetRef ref, Dealer d, MockDatabaseService db) {
    final dealerSales = db.sales.where((s) => s.partyId == d.id).toList();

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
                    Text('Dealer Profile', style: AppTextStyles.h3),
                    const Divider(height: 24),
                    _buildInfoRow('Dealer ID', d.id),
                    _buildInfoRow('Store Name', d.name),
                    _buildInfoRow('Company LLP / Name', d.companyName),
                    _buildInfoRow('Contact Person', d.contactPerson),
                    _buildInfoRow('Phone Number', d.mobile),
                    _buildInfoRow('Email Address', d.email),
                    _buildInfoRow('GST Identification', d.gstNumber),
                    _buildInfoRow('Store Address', d.address),
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
                    Text('Outstanding Balance', style: AppTextStyles.h3),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Receivables:', style: AppTextStyles.bodyMedium),
                        Text(
                          Formatters.formatCurrency(d.outstandingAmount),
                          style: AppTextStyles.h2.copyWith(color: d.outstandingAmount > 0 ? AppColors.dangerText : AppColors.successText),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow('Created Date', Formatters.formatDate(d.createdAt)),
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
            ErpColumn(title: 'Total Invoiced', isNumeric: true),
            ErpColumn(title: 'Outstanding Due', isNumeric: true),
            ErpColumn(title: 'Status'),
          ],
          rows: dealerSales.map((s) {
            return [
              InkWell(
                onTap: () => ref.read(activeRecordDetailsStackProvider.notifier).push(s.id, 'invoice', details.parentSection),
                child: Text(s.invoiceNumber, style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary)),
              ),
              Text(Formatters.formatDate(s.saleDate), style: AppTextStyles.bodySmall),
              Text(Formatters.formatCurrency(s.totalAmount), style: AppTextStyles.bodyBold),
              Text(
                Formatters.formatCurrency(s.pendingAmount),
                style: AppTextStyles.bodyBold.copyWith(color: s.pendingAmount > 0 ? AppColors.dangerText : AppColors.textMuted),
              ),
              Text(s.statusLabel, style: AppTextStyles.bodySmall),
            ];
          }).toList(),
        ),
      ],
    );
  }

  // -----------------------------------------------------------------
  // 7. Architect Details
  // -----------------------------------------------------------------
  Widget _buildArchitectDetails(BuildContext context, WidgetRef ref, Architect a, MockDatabaseService db) {
    final architectCommissions = db.commissions.where((c) => c.architectId == a.id).toList();

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
                    Text('Architect Profile', style: AppTextStyles.h3),
                    const Divider(height: 24),
                    _buildInfoRow('Architect ID', a.id),
                    _buildInfoRow('Name', a.name),
                    _buildInfoRow('Design Studio / Firm', a.companyName),
                    _buildInfoRow('Contact Mobile', a.mobile),
                    _buildInfoRow('Email Address', a.email ?? '-'),
                    _buildInfoRow('GST Number', a.gstNumber),
                    _buildInfoRow('Studio Address', a.address),
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
                    Text('Commission Ledger Summary', style: AppTextStyles.h3),
                    const Divider(height: 24),
                    _buildInfoRow('Default Commission Rate', '${a.defaultCommissionRate}%'),
                    _buildInfoRow('Total Commission Earned', Formatters.formatCurrency(a.totalCommissionEarned)),
                    _buildInfoRow('Pending Review', Formatters.formatCurrency(a.pendingCommission)),
                    _buildInfoRow('Approved (Pending Payout)', Formatters.formatCurrency(a.approvedCommission)),
                    _buildInfoRow('Paid commissions', Formatters.formatCurrency(a.paidCommission)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text('Commission Vouchers History', style: AppTextStyles.h2),
        const SizedBox(height: 12),
        ErpDataTable(
          columns: const [
            ErpColumn(title: 'Voucher No'),
            ErpColumn(title: 'Linked Invoice'),
            ErpColumn(title: 'Project Scope'),
            ErpColumn(title: 'Sale Net Valuation', isNumeric: true),
            ErpColumn(title: 'Commission Amount', isNumeric: true),
            ErpColumn(title: 'Status'),
          ],
          rows: architectCommissions.map((c) {
            return [
              Text(c.commissionNumber, style: AppTextStyles.bodyBold),
              InkWell(
                onTap: () => ref.read(activeRecordDetailsStackProvider.notifier).push(c.saleInvoiceId, 'invoice', details.parentSection),
                child: Text(c.saleInvoiceNumber, style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary)),
              ),
              Text(c.projectName ?? '-', style: AppTextStyles.bodySmall),
              Text(Formatters.formatCurrency(c.saleAmount), style: AppTextStyles.bodySmall),
              Text(Formatters.formatCurrency(c.commissionAmount), style: AppTextStyles.bodyBold.copyWith(color: AppColors.purple)),
              Text(c.status.toString().split('.').last.toUpperCase(), style: AppTextStyles.bodySmall),
            ];
          }).toList(),
        ),
      ],
    );
  }

  // -----------------------------------------------------------------
  // 8. Project Details
  // -----------------------------------------------------------------
  Widget _buildProjectDetails(BuildContext context, WidgetRef ref, Project prj, MockDatabaseService db) {
    final projectInvoices = db.sales.where((s) => s.projectId == prj.id).toList();

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
                    Text('Project Scope Specifications', style: AppTextStyles.h3),
                    const Divider(height: 24),
                    _buildInfoRow('Project ID', prj.id),
                    _buildInfoRow('Project Scope Name', prj.name),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Linked Customer:', style: AppTextStyles.bodyMedium),
                        if (prj.customerId != null)
                          InkWell(
                            onTap: () => ref.read(activeRecordDetailsStackProvider.notifier).push(prj.customerId!, 'customer', details.parentSection),
                            child: Text(prj.customerName ?? '', style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary, decoration: TextDecoration.underline)),
                          )
                        else
                          Text('Direct Client', style: AppTextStyles.bodyBold),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Lead Architect:', style: AppTextStyles.bodyMedium),
                        if (prj.architectId != null)
                          InkWell(
                            onTap: () => ref.read(activeRecordDetailsStackProvider.notifier).push(prj.architectId!, 'architect', details.parentSection),
                            child: Text(prj.architectName ?? '', style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary, decoration: TextDecoration.underline)),
                          )
                        else
                          Text('None', style: AppTextStyles.bodyBold),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow('Start Date', Formatters.formatDate(prj.startDate)),
                    _buildInfoRow('Expected Completion Date', Formatters.formatDate(prj.expectedCompletionDate)),
                    _buildInfoRow('Project Notes', prj.notes ?? '-'),
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
                    Text('Project Sales Summary', style: AppTextStyles.h3),
                    const Divider(height: 24),
                    _buildInfoRow('Total Sales Invoiced', Formatters.formatCurrency(prj.totalSalesAmount)),
                    _buildInfoRow('Total Commission Generated', Formatters.formatCurrency(prj.totalCommissionAmount)),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Project Status:', style: AppTextStyles.bodyBold),
                        Text(prj.statusLabel.toUpperCase(), style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text('Project Sales Invoices History', style: AppTextStyles.h2),
        const SizedBox(height: 12),
        ErpDataTable(
          columns: const [
            ErpColumn(title: 'Invoice Number'),
            ErpColumn(title: 'Date'),
            ErpColumn(title: 'Total Amount', isNumeric: true),
            ErpColumn(title: 'Outstanding Due', isNumeric: true),
            ErpColumn(title: 'Status'),
          ],
          rows: projectInvoices.map((s) {
            return [
              InkWell(
                onTap: () => ref.read(activeRecordDetailsStackProvider.notifier).push(s.id, 'invoice', details.parentSection),
                child: Text(s.invoiceNumber, style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary)),
              ),
              Text(Formatters.formatDate(s.saleDate), style: AppTextStyles.bodySmall),
              Text(Formatters.formatCurrency(s.totalAmount), style: AppTextStyles.bodyBold),
              Text(
                Formatters.formatCurrency(s.pendingAmount),
                style: AppTextStyles.bodyBold.copyWith(color: s.pendingAmount > 0 ? AppColors.dangerText : AppColors.textMuted),
              ),
              Text(s.statusLabel, style: AppTextStyles.bodySmall),
            ];
          }).toList(),
        ),
      ],
    );
  }

  void _showSaleDocumentPdfDialog(BuildContext context, Sale s, MockDatabaseService db) {
    final isInvoice = s.documentType == SalesDocumentType.invoice;
    final title = isInvoice ? 'TAX INVOICE' : 'QUOTATION';
    
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.lgBorderRadius),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$title PDF Preview', style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.black54),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
          content: SizedBox(
            width: 820,
            height: 600,
            child: SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300, width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'DELUZEX LIGHTING PVT. LTD.',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'GSTIN: 27AABCO8890K1Z9 | sales@deluzex.com',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                            ),
                            Text(
                              ' Borivali East, Mumbai, Maharashtra 400066',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                        const Icon(Icons.flash_on, size: 48, color: AppColors.primary),
                      ],
                    ),
                    const Divider(color: Colors.black87, thickness: 1.5, height: 24),

                    Center(
                      child: Text(
                        title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87, letterSpacing: 1.2),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Metadata
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isInvoice ? 'Invoice No: ${s.invoiceNumber}' : 'Quotation No: ${s.invoiceNumber}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                            Text(
                              'Date: ${Formatters.formatDate(s.saleDate)}',
                              style: const TextStyle(fontSize: 11, color: Colors.black87),
                            ),
                            if (!isInvoice && s.validUntil != null)
                              Text(
                                'Valid Until: ${Formatters.formatDate(s.validUntil!)}',
                                style: const TextStyle(fontSize: 11, color: Colors.black87),
                              ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (s.salesOrderNumber != null)
                              Text('Sales Order: ${s.salesOrderNumber}', style: const TextStyle(fontSize: 11, color: Colors.black87)),
                            if (s.quotationReferenceId != null)
                              Text('Ref Quote ID: ${s.quotationReferenceId}', style: const TextStyle(fontSize: 11, color: Colors.black87)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Client details
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('BILL TO:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54)),
                                const SizedBox(height: 4),
                                Text(s.partyName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87)),
                                Text('Client ID: ${s.partyId}', style: const TextStyle(fontSize: 11, color: Colors.black87)),
                              ],
                            ),
                          ),
                          if (s.projectName != null)
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('PROJECT LOCATION:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54)),
                                  const SizedBox(height: 4),
                                  Text(s.projectName!, style: const TextStyle(fontSize: 11, color: Colors.black87)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Items table
                    Table(
                      border: TableBorder.all(color: Colors.grey.shade300),
                      children: [
                        TableRow(
                          decoration: BoxDecoration(color: Colors.grey.shade200),
                          children: const [
                            Padding(padding: EdgeInsets.all(6), child: Text('Sr No', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold))),
                            Padding(padding: EdgeInsets.all(6), child: Text('Item SKU', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold))),
                            Padding(padding: EdgeInsets.all(6), child: Text('Description', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold))),
                            Padding(padding: EdgeInsets.all(6), child: Text('Qty', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold))),
                            Padding(padding: EdgeInsets.all(6), child: Text('Rate', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold))),
                            Padding(padding: EdgeInsets.all(6), child: Text('Discount', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold))),
                            Padding(padding: EdgeInsets.all(6), child: Text('Total', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold))),
                          ],
                        ),
                        ...List.generate(s.items.length, (idx) {
                          final item = s.items[idx];
                          return TableRow(
                            children: [
                              Padding(padding: const EdgeInsets.all(6), child: Text('${idx + 1}', style: const TextStyle(fontSize: 9))),
                              Padding(padding: const EdgeInsets.all(6), child: Text(item.finishedProductCode, style: const TextStyle(fontSize: 9))),
                              Padding(padding: const EdgeInsets.all(6), child: Text(item.finishedProductName, style: const TextStyle(fontSize: 9))),
                              Padding(padding: const EdgeInsets.all(6), child: Text('${item.quantity} ${item.unit}', style: const TextStyle(fontSize: 9))),
                              Padding(padding: const EdgeInsets.all(6), child: Text(Formatters.formatCurrency(item.rate), style: const TextStyle(fontSize: 9))),
                              Padding(padding: const EdgeInsets.all(6), child: Text(Formatters.formatCurrency(item.discountAmount), style: const TextStyle(fontSize: 9))),
                              Padding(padding: const EdgeInsets.all(6), child: Text(Formatters.formatCurrency(item.lineTotal), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold))),
                            ],
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Summary block
                    Align(
                      alignment: Alignment.centerRight,
                      child: SizedBox(
                        width: 300,
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Subtotal:', style: TextStyle(fontSize: 10, color: Colors.black54)),
                                Text(Formatters.formatCurrency(s.subtotalAmount), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total Discount:', style: TextStyle(fontSize: 10, color: Colors.black54)),
                                Text('- ${Formatters.formatCurrency(s.discountAmount)}', style: const TextStyle(fontSize: 10)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('GST Output Tax (18%):', style: TextStyle(fontSize: 10, color: Colors.black54)),
                                Text(Formatters.formatCurrency(s.gstAmount), style: const TextStyle(fontSize: 10)),
                              ],
                            ),
                            const Divider(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('GRAND TOTAL:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                Text(Formatters.formatCurrency(s.totalAmount), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Footer terms and signatures
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Prepared By: Sales Desk', style: TextStyle(fontSize: 9, color: Colors.black54)),
                            const SizedBox(height: 24),
                            Container(width: 120, height: 1, color: Colors.grey),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('Authorized Signatory', style: TextStyle(fontSize: 9, color: Colors.black54)),
                            const SizedBox(height: 24),
                            Container(width: 120, height: 1, color: Colors.grey),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            ErpButton(
              text: 'Download / Print PDF',
              icon: Icons.print,
              onPressed: () {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Document exported to system downloads successfully!'), backgroundColor: AppColors.success),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildSaleDetails(BuildContext context, WidgetRef ref, Sale s, MockDatabaseService db) {
    final payHistory = db.payments.where((p) => p.referenceDocumentId == s.id).toList();

    // Fetch customer details
    String customerCode = '-';
    String customerEmail = '-';
    String customerPhone = '-';
    String billingAddress = '-';
    String shippingAddress = '-';

    if (s.partyType == PartyType.customer) {
      final cust = db.customers.firstWhere((c) => c.id == s.partyId, orElse: () => db.customers.first);
      customerCode = cust.id;
      customerEmail = cust.email;
      customerPhone = cust.mobile;
      billingAddress = cust.address;
      shippingAddress = cust.address;
    } else {
      final dlr = db.dealers.firstWhere((d) => d.id == s.partyId, orElse: () => db.dealers.first);
      customerCode = dlr.id;
      customerEmail = dlr.email;
      customerPhone = dlr.mobile;
      billingAddress = dlr.address;
      shippingAddress = dlr.address;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                    
                    if (s.documentType == SalesDocumentType.salesReturn) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Original Invoice Link:', style: AppTextStyles.bodyMedium),
                          if (s.originalInvoiceId != null)
                            InkWell(
                              onTap: () => ref.read(activeRecordDetailsStackProvider.notifier).push(s.originalInvoiceId!, 'invoice', details.parentSection),
                              child: Text(s.originalInvoiceNumber ?? 'Invoice Ref', style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary, decoration: TextDecoration.underline)),
                            )
                          else
                            Text(s.originalInvoiceNumber ?? '-', style: AppTextStyles.bodyBold),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow('Return Main Reason', s.returnReason ?? '-'),
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
                    Text('Calculated Totals & Actions', style: AppTextStyles.h3),
                    const Divider(height: 24),
                    _buildInfoRow('Subtotal Amount', Formatters.formatCurrency(s.subtotalAmount)),
                    _buildInfoRow('Discounts Amount', Formatters.formatCurrency(s.discountAmount)),
                    _buildInfoRow('GST Output Tax (18%)', Formatters.formatCurrency(s.gstAmount)),
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Grand Total Amount:', style: AppTextStyles.bodyBold),
                        Text(Formatters.formatCurrency(s.totalAmount), style: AppTextStyles.h2.copyWith(color: AppColors.primary)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow('Amount Received / Paid', Formatters.formatCurrency(s.paidAmount)),
                    _buildInfoRow('Outstanding Receivables', Formatters.formatCurrency(s.pendingAmount)),
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
                      if (s.quotationStatus == QuotationStatus.draft || s.quotationStatus == QuotationStatus.sent || s.quotationStatus == null) ...[
                        Row(
                          children: [
                            Expanded(
                              child: ErpButton(
                                text: 'Approve & Auto-SO',
                                icon: Icons.check_circle_outline,
                                onPressed: () {
                                  db.approveQuotation(s.id);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Quotation Approved! Sales Order generated automatically.'), backgroundColor: AppColors.success),
                                  );
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
                                text: 'Reject Quotation',
                                isOutlined: true,
                                icon: Icons.cancel_outlined,
                                onPressed: () {
                                  db.rejectQuotation(s.id);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Quotation Rejected.'), backgroundColor: AppColors.danger),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],

                      // Linked SO Clickable if approved
                      if (s.salesOrderReferenceId != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: AppRadius.smBorderRadius),
                          child: InkWell(
                            onTap: () => ref.read(activeRecordDetailsStackProvider.notifier).push(s.salesOrderReferenceId!, 'salesOrder', details.parentSection),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Sales Order Link:', style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary)),
                                Row(
                                  children: [
                                    Text('View Sales Order ', style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary)),
                                    const Icon(Icons.arrow_right_alt, color: AppColors.primary),
                                  ],
                                )
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
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
                      
                      // Pre-fill Create Invoice option if Sales Order is DONE
                      if (s.salesOrderStatus == SalesOrderStatus.done && s.salesOrderReferenceId == null) ...[
                        Row(
                          children: [
                            Expanded(
                              child: ErpButton(
                                text: 'Create Invoice',
                                icon: Icons.receipt_long,
                                onPressed: () {
                                  // Pre-fill in Riverpod state and navigate to creation page
                                  ref.read(salesCreateDocTypeProvider.notifier).state = SalesDocumentType.invoice;
                                  ref.read(salesCreateSourceDocIdProvider.notifier).state = s.id;
                                  ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.createSale;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],

                    // Invoice actions
                    if (s.documentType == SalesDocumentType.invoice && s.status != SaleStatus.cancelled) ...[
                      Row(
                        children: [
                          Expanded(
                            child: ErpButton(
                              text: 'Create Sales Return',
                              isOutlined: true,
                              icon: Icons.assignment_return_outlined,
                              onPressed: () {
                                // Pre-fill in Riverpod and redirect to creation
                                ref.read(salesCreateDocTypeProvider.notifier).state = SalesDocumentType.salesReturn;
                                ref.read(salesCreateSourceDocIdProvider.notifier).state = s.id;
                                ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.createSale;
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
                              text: 'Record Payment',
                              icon: Icons.payments_outlined,
                              onPressed: () {
                                // Switch view to customer payments tab to record payment
                                ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.customerPayments;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Sales Return actions
                    if (s.documentType == SalesDocumentType.salesReturn && s.salesReturnStatus == SalesReturnStatus.requested) ...[
                      Row(
                        children: [
                          Expanded(
                            child: ErpButton(
                              text: 'Complete & Add Stock',
                              icon: Icons.check,
                              onPressed: () {
                                db.updateSalesReturnStatus(s.id, SalesReturnStatus.completed);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Sales Return Completed! Stock balances adjusted.'), backgroundColor: AppColors.success),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Standard PDF viewing actions
                    if (s.documentType == SalesDocumentType.quotation || s.documentType == SalesDocumentType.invoice) ...[
                      Row(
                        children: [
                          Expanded(
                            child: ErpButton(
                              text: 'View PDF / Print',
                              isOutlined: true,
                              icon: Icons.picture_as_pdf,
                              onPressed: () {
                                if (s.documentType == SalesDocumentType.quotation) {
                                  QuotationPdfPreviewDialog.show(context, s, db);
                                } else {
                                  _showSaleDocumentPdfDialog(context, s, db);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Standard attachment details view
                    const SizedBox(height: 12),
                    Text('Supporting Attachments', style: AppTextStyles.bodyBold),
                    const SizedBox(height: 8),
                    StatefulBuilder(
                      builder: (ctx, setAttachmentState) {
                        return s.attachmentUrl != null
                            ? Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceMuted,
                                  borderRadius: AppRadius.smBorderRadius,
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.picture_as_pdf, color: AppColors.danger, size: 28),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(s.attachmentUrl!, style: AppTextStyles.bodyBold.copyWith(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                                          Text('Size: 185 KB | Type: PDF Document', style: AppTextStyles.bodySmall),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textMuted),
                                      onPressed: () {
                                        db.sales[db.sales.indexOf(s)] = s.copyWith(attachmentUrl: null);
                                        db.notifyListeners();
                                        setAttachmentState(() {});
                                      },
                                    ),
                                  ],
                                ),
                              )
                            : InkWell(
                                onTap: () {
                                  db.sales[db.sales.indexOf(s)] = s.copyWith(
                                    attachmentUrl: 'Signed_Supporting_Doc_${s.invoiceNumber}.pdf',
                                  );
                                  db.notifyListeners();
                                  setAttachmentState(() {});
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: AppColors.border, style: BorderStyle.solid),
                                    borderRadius: AppRadius.smBorderRadius,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.cloud_upload_outlined, color: AppColors.primary, size: 18),
                                      const SizedBox(width: 8),
                                      Text('Choose File / Upload Document', style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary)),
                                    ],
                                  ),
                                ),
                              );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text('Items List / Details', style: AppTextStyles.h2),
        const SizedBox(height: 12),
        ErpDataTable(
          columns: [
            ErpColumn(title: 'Product SKU'),
            ErpColumn(title: 'Product Name'),
            ErpColumn(title: 'Quantity'),
            ErpColumn(title: 'Rate', isNumeric: true),
            ErpColumn(title: 'Discount Applied', isNumeric: true),
            ErpColumn(title: 'GST Tax', isNumeric: true),
            if (s.documentType == SalesDocumentType.salesReturn) ErpColumn(title: 'Return Condition'),
            ErpColumn(title: 'Line Total', isNumeric: true),
          ],
          rows: s.items.map((item) {
            return [
              InkWell(
                onTap: () => ref.read(activeRecordDetailsStackProvider.notifier).push(item.finishedProductId, 'finishedProduct', details.parentSection),
                child: Text(item.finishedProductCode, style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary)),
              ),
              Text(item.finishedProductName, style: AppTextStyles.bodyMedium),
              Text('${item.quantity} ${item.unit}', style: AppTextStyles.bodyMedium),
              Text(Formatters.formatCurrency(item.rate), style: AppTextStyles.bodySmall),
              Text(Formatters.formatCurrency(item.discountAmount), style: AppTextStyles.bodySmall),
              Text('${item.gstPercent}%', style: AppTextStyles.bodySmall),
              if (s.documentType == SalesDocumentType.salesReturn) Text(item.productCondition ?? 'Good/Saleable', style: AppTextStyles.bodySmall),
              Text(Formatters.formatCurrency(item.lineTotal), style: AppTextStyles.bodyBold),
            ];
          }).toList(),
        ),
        if (payHistory.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Payments Received against this Invoice', style: AppTextStyles.h2),
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
        ]
      ],
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

  // Common UI builder row helper
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.bodyMedium),
          Text(value, style: AppTextStyles.bodyBold),
        ],
      ),
    );
  }
}
