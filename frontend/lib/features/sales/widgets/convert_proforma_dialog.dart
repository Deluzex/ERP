import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/models/finished_product_model.dart';
import '../../../core/models/rbac_models.dart';
import '../../../core/models/sale_model.dart';
import '../../../core/models/stock_movement_model.dart';
import '../../../core/models/whatsapp_models.dart';
import '../../../core/models/notification_model.dart';
import '../../../core/utils/document_sharing_service.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/widgets/erp_button.dart';
import '../../../core/widgets/erp_status_badge.dart';
import '../../../shared/providers/app_state_providers.dart';
import '../../../shared/services/mock_database_service.dart';

enum ProductFulfillmentAction {
  purchase,
  production,
}

extension ProductFulfillmentActionExt on ProductFulfillmentAction {
  String get label {
    switch (this) {
      case ProductFulfillmentAction.purchase:
        return 'PURCHASE';
      case ProductFulfillmentAction.production:
        return 'PRODUCTION';
    }
  }

  String get description {
    switch (this) {
      case ProductFulfillmentAction.purchase:
        return 'Procure required shortage from external vendors / suppliers';
      case ProductFulfillmentAction.production:
        return 'Schedule in-house manufacturing / assembly at the factory';
    }
  }

  IconData get icon {
    switch (this) {
      case ProductFulfillmentAction.purchase:
        return Icons.shopping_bag_outlined;
      case ProductFulfillmentAction.production:
        return Icons.precision_manufacturing_outlined;
    }
  }
}

class ProductShortageDetail {
  final SaleLineItem lineItem;
  final FinishedProduct? product;
  final double requiredQuantity;
  final double availableStock;
  final double shortageQuantity;

  const ProductShortageDetail({
    required this.lineItem,
    this.product,
    required this.requiredQuantity,
    required this.availableStock,
    required this.shortageQuantity,
  });

  bool get hasShortage => shortageQuantity > 0;
}

class ConvertProformaDialog extends ConsumerStatefulWidget {
  final Sale proforma;

  const ConvertProformaDialog({
    super.key,
    required this.proforma,
  });

  static Future<void> show(BuildContext context, Sale proforma) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ConvertProformaDialog(proforma: proforma),
    );
  }

  @override
  ConsumerState<ConvertProformaDialog> createState() => _ConvertProformaDialogState();
}

class _ConvertProformaDialogState extends ConsumerState<ConvertProformaDialog> {
  ProductFulfillmentAction _selectedAction = ProductFulfillmentAction.production;
  String? _selectedUserId;
  DateTime _deliveryDate = DateTime.now().add(const Duration(days: 14));
  final TextEditingController _notesCtrl = TextEditingController();
  bool _isProcessing = false;
  Sale? _createdSalesOrder;
  AppUser? _assignedUser;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final db = ref.read(databaseServiceProvider);
    _selectOptimalUserForAction(_selectedAction, db);
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  List<ProductShortageDetail> _analyzeProductStock(MockDatabaseService db, List<SaleLineItem> items) {
    return items.map((item) {
      final fp = db.finishedProducts.where((p) => p.id == item.finishedProductId || p.itemCode == item.finishedProductCode).firstOrNull;
      final available = fp?.availableStock ?? 0.0;
      final required = item.quantity;
      final shortage = (required - available).clamp(0.0, double.infinity);

      return ProductShortageDetail(
        lineItem: item,
        product: fp,
        requiredQuantity: required,
        availableStock: available,
        shortageQuantity: shortage,
      );
    }).toList();
  }

  List<AppUser> _getEligibleUsersForAction(ProductFulfillmentAction action, MockDatabaseService db) {
    final activeUsers = db.users.where((u) => u.isActive).toList();

    if (action == ProductFulfillmentAction.purchase) {
      final purchaseUsers = activeUsers.where((u) {
        return u.primaryRoleId == 'purchase_manager' ||
            u.primaryRoleId == 'inventory_manager' ||
            u.assignedRoleIds.contains('purchase_manager') ||
            u.assignedRoleIds.contains('inventory_manager');
      }).toList();

      if (purchaseUsers.isNotEmpty) return purchaseUsers;
    } else {
      final productionUsers = activeUsers.where((u) {
        return u.primaryRoleId == 'production_manager' ||
            u.assignedRoleIds.contains('production_manager');
      }).toList();

      if (productionUsers.isNotEmpty) return productionUsers;
    }

    // Fallback if no specific role matches
    return activeUsers;
  }

  void _selectOptimalUserForAction(ProductFulfillmentAction action, MockDatabaseService db) {
    final eligible = _getEligibleUsersForAction(action, db);
    if (eligible.isEmpty) {
      _selectedUserId = null;
      return;
    }

    if (_selectedUserId == null || !eligible.any((u) => u.id == _selectedUserId)) {
      _selectedUserId = eligible.first.id;
    }
  }

  String _buildRequisitionWhatsAppMessage({
    required Sale salesOrder,
    required AppUser responsibleUser,
    required ProductFulfillmentAction action,
    required List<ProductShortageDetail> shortages,
    String? notes,
  }) {
    final actionHeader = action == ProductFulfillmentAction.purchase
        ? 'New Purchase Requirement'
        : 'New Production Requirement';

    final buffer = StringBuffer();
    buffer.writeln('--------------------------------------------------');
    buffer.writeln(actionHeader);
    buffer.writeln();
    buffer.writeln('Sales Order: ${salesOrder.invoiceNumber}');
    buffer.writeln('Customer: ${salesOrder.partyName}');

    for (final s in shortages) {
      buffer.writeln('Product: ${s.lineItem.finishedProductName}');
      buffer.writeln('Required Quantity: ${Formatters.formatNumber(s.requiredQuantity)}');
      buffer.writeln('Available Stock: ${Formatters.formatNumber(s.availableStock)}');
      buffer.writeln('Shortage: ${Formatters.formatNumber(s.shortageQuantity)}');
    }

    if (notes != null && notes.trim().isNotEmpty) {
      buffer.writeln('Notes: ${notes.trim()}');
    }
    buffer.write('--------------------------------------------------');

    return buffer.toString();
  }

  Future<void> _handleConversion() async {
    if (_isProcessing) return;

    final db = ref.read(databaseServiceProvider);
    final eligibleUsers = _getEligibleUsersForAction(_selectedAction, db);
    final user = eligibleUsers.where((u) => u.id == _selectedUserId).firstOrNull ??
        db.users.where((u) => u.id == _selectedUserId).firstOrNull;

    if (user == null) {
      setState(() => _errorMessage = 'Please select a responsible person before proceeding.');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a valid responsible person before proceeding.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      // 1. Ensure proforma items are hydrated
      final hydratedProforma = widget.proforma.items.isEmpty
          ? await db.getProformaDetailAsync(widget.proforma.id)
          : widget.proforma;

      if (hydratedProforma.items.isEmpty) {
        throw Exception('Proforma invoice contains no line items to convert.');
      }

      // 2. Identify shortage items
      final stockAnalysis = _analyzeProductStock(db, hydratedProforma.items);
      final shortageItems = stockAnalysis.where((s) => s.hasShortage).toList();

      // 3. Generate Sales Order Number
      final soNumber = 'DLZ/SO/2026/${db.nextSalesOrderNumber.toString().padLeft(4, '0')}';
      final role = db.getUserRole(user);
      final notesText = _notesCtrl.text.trim();

      // 4. Create Activity Log
      final activityLog = DocumentActivityLog(
        id: IdGenerator.generateId('LOG'),
        action: 'CONVERTED_FROM_PROFORMA',
        performedBy: db.currentUser.name,
        timestamp: DateTime.now(),
        details: 'Converted from Proforma ${hydratedProforma.invoiceNumber}. Action: [${_selectedAction.label}] assigned to ${user.name} (${role.name}, ${user.mobile}). Shortage items: ${shortageItems.length}.',
        statusBefore: 'Proforma Issued',
        statusAfter: 'Sales Order Active',
      );

      // 5. Build Sales Order Model
      final newSo = Sale(
        id: IdGenerator.generateId('SO'),
        invoiceNumber: soNumber,
        documentType: SalesDocumentType.salesOrder,
        partyType: hydratedProforma.partyType,
        partyId: hydratedProforma.partyId,
        partyName: hydratedProforma.partyName,
        customerContactPerson: hydratedProforma.customerContactPerson,
        customerMobile: hydratedProforma.customerMobile,
        customerEmail: hydratedProforma.customerEmail,
        customerGstNumber: hydratedProforma.customerGstNumber,
        billingAddress: hydratedProforma.billingAddress,
        shippingAddress: hydratedProforma.shippingAddress,
        projectId: hydratedProforma.projectId,
        projectName: hydratedProforma.projectName,
        architectId: hydratedProforma.architectId,
        architectName: hydratedProforma.architectName,
        salesExecutive: db.currentUser.name,
        salesOrderNumber: soNumber,
        proformaReferenceId: hydratedProforma.id,
        proformaNumber: hydratedProforma.invoiceNumber,
        quotationReferenceId: hydratedProforma.quotationReferenceId,
        saleDate: DateTime.now(),
        deliveryDate: _deliveryDate,
        items: hydratedProforma.items.map((i) => i.copyWith()).toList(),
        subtotalAmount: hydratedProforma.subtotalAmount,
        discountAmount: hydratedProforma.discountAmount,
        taxableAmount: hydratedProforma.taxableAmount,
        cgstAmount: hydratedProforma.cgstAmount,
        sgstAmount: hydratedProforma.sgstAmount,
        igstAmount: hydratedProforma.igstAmount,
        gstAmount: hydratedProforma.gstAmount,
        totalAmount: hydratedProforma.totalAmount,
        paidAmount: hydratedProforma.paidAmount,
        pendingAmount: hydratedProforma.pendingAmount,
        paymentMode: hydratedProforma.paymentMode,
        status: SaleStatus.active,
        salesOrderStatus: _selectedAction == ProductFulfillmentAction.production
            ? SalesOrderStatus.productionPending
            : SalesOrderStatus.pending,
        notes: notesText.isNotEmpty
            ? '[${_selectedAction.label} ASSIGNED: ${user.name} (${role.name})] $notesText'
            : '[${_selectedAction.label} ASSIGNED: ${user.name} (${role.name})]',
        termsAndConditions: hydratedProforma.termsAndConditions,
        activityLogs: [activityLog],
        createdAt: DateTime.now(),
      );

      // 6. Save Sales Order in database
      Sale createdSO;
      try {
        createdSO = await db.createSalesOrderAsync(newSo, autoAllocate: true);
      } catch (remoteErr) {
        final idx = db.sales.indexWhere((s) => s.id == newSo.id);
        if (idx == -1) {
          db.sales.insert(0, newSo);
        } else {
          db.sales[idx] = newSo;
        }
        createdSO = newSo;
      }

      // 7. Update Proforma Status to Converted
      final piIndex = db.sales.indexWhere((s) => s.id == hydratedProforma.id);
      if (piIndex != -1) {
        db.sales[piIndex] = db.sales[piIndex].copyWith(
          proformaStatus: ProformaStatus.converted,
          salesOrderReferenceId: createdSO.id,
          salesOrderNumber: createdSO.invoiceNumber,
        );
      }

      // 8. Log Access and Security Audit Trail
      db.logAccessAttempt(
        userId: db.currentUser.id,
        userName: db.currentUser.name,
        userRole: db.getUserRole(db.currentUser).name,
        module: ErpModule.sales,
        action: ErpAction.create,
        sectionName: 'Sales Orders',
        status: 'allowed',
        notes: 'Sales Order ${createdSO.invoiceNumber} created from ${hydratedProforma.invoiceNumber}. ${_selectedAction.label} assigned to ${user.name} (${user.email}, ${user.mobile}).',
      );

      // 9. Record Notification in Existing Notification Architecture for shortage items
      for (final shortage in shortageItems) {
        final shortageQty = (shortage.requiredQuantity - shortage.availableStock).clamp(0.0, double.infinity);
        final notifType = _selectedAction == ProductFulfillmentAction.purchase
            ? 'purchase_requisition'
            : 'production_requisition';
        final targetRole = _selectedAction == ProductFulfillmentAction.purchase
            ? 'purchase_manager'
            : 'production_manager';
        final targetRoute = _selectedAction == ProductFulfillmentAction.purchase
            ? '/purchase/orders'
            : '/production/orders';

        final notif = NotificationItem(
          id: IdGenerator.generateId('NOTIF'),
          title: '${_selectedAction.label} Requisition: ${shortage.lineItem.finishedProductName}',
          message: 'Requisition of $shortageQty ${shortage.lineItem.unit} requested for Sales Order ${createdSO.invoiceNumber} (Customer: ${createdSO.partyName}).',
          notificationType: notifType,
          targetRole: targetRole,
          recipientUserId: user.id,
          recipientName: user.name,
          recipientEmail: user.email,
          sourceModule: 'sales',
          relatedEntityType: 'sales_order',
          relatedEntityId: createdSO.id,
          data: {
            'salesOrderNumber': createdSO.invoiceNumber,
            'salesOrderId': createdSO.id,
            'customerName': createdSO.partyName,
            'productName': shortage.lineItem.finishedProductName,
            'productSku': shortage.lineItem.finishedProductCode,
            'requestedQuantity': shortage.requiredQuantity,
            'availableStock': shortage.availableStock,
            'shortageQuantity': shortageQty,
            'requestType': _selectedAction.label,
            'sourceModule': 'Sales Orders',
            'route': targetRoute,
          },
          isRead: false,
          createdAt: DateTime.now(),
        );

        db.createNotification(notif);
        await db.createNotificationAsync(notif);

        final msg = _buildRequisitionWhatsAppMessage(
          salesOrder: createdSO,
          responsibleUser: user,
          action: _selectedAction,
          shortages: [shortage],
          notes: notesText,
        );

        db.triggerLowStockWhatsAppAlert(
          itemId: shortage.lineItem.finishedProductId,
          itemName: shortage.lineItem.finishedProductName,
          itemCode: shortage.lineItem.finishedProductCode,
          itemType: 'Finished Product',
          currentStock: shortage.availableStock,
          minStock: shortage.requiredQuantity,
          reorderLevel: shortage.requiredQuantity,
          unit: shortage.lineItem.unit,
          recipientName: user.name,
          recipientWhatsApp: user.mobile,
          messageBody: msg,
        );

        await db.triggerLowStockAlertAsync(
          itemId: shortage.lineItem.finishedProductId,
          itemType: ItemType.finishedProduct,
          recipientId: user.id,
          recipientName: user.name,
          recipientWhatsApp: user.mobile,
          customMessage: msg,
        );
      }

      setState(() {
        _isProcessing = false;
        _createdSalesOrder = createdSO;
        _assignedUser = user;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _errorMessage = e.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error converting proforma to sales order: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  void _sendWhatsAppNotification(Sale so, AppUser user, MockDatabaseService db, List<ProductShortageDetail> shortages) {
    final cleaned = DocumentSharingService.cleanPhoneNumber(user.mobile);
    if (cleaned.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${user.name} does not have a valid mobile/WhatsApp number stored.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final message = _buildRequisitionWhatsAppMessage(
      salesOrder: so,
      responsibleUser: user,
      action: _selectedAction,
      shortages: shortages.isNotEmpty ? shortages : _analyzeProductStock(db, so.items),
      notes: _notesCtrl.text.trim(),
    );

    // Log message in unified WhatsApp audit log
    db.logWhatsAppMessage(
      WhatsAppMessageLog(
        id: IdGenerator.generateId('WLOG'),
        messageType: '${_selectedAction.label} Requisition',
        recipientName: user.name,
        recipientNumber: user.mobile,
        relatedEntityType: 'Sales Order',
        relatedEntityId: so.id,
        relatedEntityNumber: so.invoiceNumber,
        messageText: message,
        sentAt: DateTime.now(),
        status: 'Sent',
      ),
    );

    // Open WhatsApp
    DocumentSharingService.shareToWhatsApp(
      phoneNumber: user.mobile,
      message: message,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening WhatsApp message for ${user.name} (${user.mobile})...'),
        backgroundColor: const Color(0xFF25D366),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseServiceProvider);
    final stockAnalysis = _analyzeProductStock(db, widget.proforma.items);
    final shortageItems = stockAnalysis.where((s) => s.hasShortage).toList();
    final sufficientItems = stockAnalysis.where((s) => !s.hasShortage).toList();

    if (_createdSalesOrder != null && _assignedUser != null) {
      return _buildSuccessView(context, _createdSalesOrder!, _assignedUser!, db, shortageItems);
    }

    final eligibleUsers = _getEligibleUsersForAction(_selectedAction, db);

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.lgBorderRadius),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      actionsPadding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.inventory_2_outlined, color: AppColors.danger, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Convert Proforma to Sales Order',
                  style: AppTextStyles.h2.copyWith(fontSize: 17),
                ),
                const SizedBox(height: 2),
                Text(
                  'Insufficient Stock Detected — select requirement decision',
                  style: AppTextStyles.caption.copyWith(color: AppColors.dangerText),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
          ),
        ],
      ),
      content: Container(
        constraints: const BoxConstraints(maxWidth: 580),
        width: double.infinity,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.1),
                    borderRadius: AppRadius.smBorderRadius,
                    border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.danger, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: AppTextStyles.caption.copyWith(color: AppColors.dangerText),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // 1. Order Summary Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: AppRadius.mdBorderRadius,
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Proforma Invoice', style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
                            Text(widget.proforma.invoiceNumber, style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Order Total Value', style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
                            Text(Formatters.formatCurrency(widget.proforma.totalAmount), style: AppTextStyles.bodyBold),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Client: ${widget.proforma.partyName}',
                            style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (widget.proforma.projectName != null)
                          Text(
                            'Project: ${widget.proforma.projectName}',
                            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 2. Shortage Items Table / List
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Products Requiring Fulfillment (${shortageItems.length} Shortage)',
                    style: AppTextStyles.bodyBold.copyWith(color: AppColors.dangerText),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.04),
                  borderRadius: AppRadius.smBorderRadius,
                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                ),
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    // Header
                    Row(
                      children: [
                        Expanded(flex: 4, child: Text('PRODUCT', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold))),
                        Expanded(flex: 2, child: Text('REQUIRED', textAlign: TextAlign.right, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold))),
                        Expanded(flex: 2, child: Text('AVAILABLE', textAlign: TextAlign.right, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold))),
                        Expanded(flex: 2, child: Text('SHORTAGE', textAlign: TextAlign.right, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold, color: AppColors.dangerText))),
                      ],
                    ),
                    const Divider(height: 12),
                    ...shortageItems.map((s) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(s.lineItem.finishedProductName, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                                  if (s.lineItem.finishedProductCode.isNotEmpty)
                                    Text(s.lineItem.finishedProductCode, style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text('${Formatters.formatNumber(s.requiredQuantity)} ${s.lineItem.unit}', textAlign: TextAlign.right, style: AppTextStyles.bodySmall),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text('${Formatters.formatNumber(s.availableStock)} ${s.lineItem.unit}', textAlign: TextAlign.right, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                '${Formatters.formatNumber(s.shortageQuantity)} ${s.lineItem.unit}',
                                textAlign: TextAlign.right,
                                style: AppTextStyles.bodyBold.copyWith(color: AppColors.dangerText),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    if (sufficientItems.isNotEmpty) ...[
                      const Divider(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.check_circle_outline, color: AppColors.success, size: 14),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${sufficientItems.length} other items in this order have sufficient stock and will be allocated directly.',
                              style: AppTextStyles.caption.copyWith(color: AppColors.successText),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // 3. SALES DECISION: PURCHASE OR PRODUCTION
              Row(
                children: [
                  const Icon(Icons.alt_route_rounded, color: AppColors.primary, size: 18),
                  const SizedBox(width: 6),
                  Text('Sales Shortage Decision *', style: AppTextStyles.bodyBold),
                ],
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  // Option 1: PURCHASE
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedAction = ProductFulfillmentAction.purchase;
                          _selectOptimalUserForAction(ProductFulfillmentAction.purchase, db);
                        });
                      },
                      borderRadius: AppRadius.mdBorderRadius,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: _selectedAction == ProductFulfillmentAction.purchase
                              ? AppColors.primary.withValues(alpha: 0.08)
                              : AppColors.surface,
                          borderRadius: AppRadius.mdBorderRadius,
                          border: Border.all(
                            color: _selectedAction == ProductFulfillmentAction.purchase
                                ? AppColors.primary
                                : AppColors.border,
                            width: _selectedAction == ProductFulfillmentAction.purchase ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Radio<ProductFulfillmentAction>(
                                  value: ProductFulfillmentAction.purchase,
                                  groupValue: _selectedAction,
                                  activeColor: AppColors.primary,
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() {
                                        _selectedAction = val;
                                        _selectOptimalUserForAction(val, db);
                                      });
                                    }
                                  },
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    '1. PURCHASE',
                                    style: AppTextStyles.bodyBold.copyWith(
                                      color: _selectedAction == ProductFulfillmentAction.purchase
                                          ? AppColors.primary
                                          : AppColors.textPrimary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Procure shortage items from external vendor',
                              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Option 2: PRODUCTION
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedAction = ProductFulfillmentAction.production;
                          _selectOptimalUserForAction(ProductFulfillmentAction.production, db);
                        });
                      },
                      borderRadius: AppRadius.mdBorderRadius,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: _selectedAction == ProductFulfillmentAction.production
                              ? AppColors.primary.withValues(alpha: 0.08)
                              : AppColors.surface,
                          borderRadius: AppRadius.mdBorderRadius,
                          border: Border.all(
                            color: _selectedAction == ProductFulfillmentAction.production
                                ? AppColors.primary
                                : AppColors.border,
                            width: _selectedAction == ProductFulfillmentAction.production ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Radio<ProductFulfillmentAction>(
                                  value: ProductFulfillmentAction.production,
                                  groupValue: _selectedAction,
                                  activeColor: AppColors.primary,
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() {
                                        _selectedAction = val;
                                        _selectOptimalUserForAction(val, db);
                                      });
                                    }
                                  },
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    '2. PRODUCTION',
                                    style: AppTextStyles.bodyBold.copyWith(
                                      color: _selectedAction == ProductFulfillmentAction.production
                                          ? AppColors.primary
                                          : AppColors.textPrimary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Manufacture shortage items in-house at plant',
                              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // 4. RESPONSIBLE PERSON SELECTION (FILTERED BY ACTION)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _selectedAction == ProductFulfillmentAction.purchase
                          ? 'Purchase Responsible Person *'
                          : 'Production Responsible Person *',
                      style: AppTextStyles.bodyBold,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${eligibleUsers.length} available',
                    style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              DropdownButtonFormField<String>(
                isExpanded: true,
                value: eligibleUsers.any((u) => u.id == _selectedUserId) ? _selectedUserId : (eligibleUsers.isNotEmpty ? eligibleUsers.first.id : null),
                decoration: InputDecoration(
                  prefixIcon: Icon(
                    _selectedAction == ProductFulfillmentAction.purchase ? Icons.person_outline : Icons.engineering_outlined,
                    size: 20,
                  ),
                  isDense: true,
                ),
                items: eligibleUsers.map((u) {
                  final role = db.getUserRole(u);
                  return DropdownMenuItem<String>(
                    value: u.id,
                    child: Text(
                      '${u.name} (${role.name}) - ${u.mobile}',
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedUserId = val);
                },
              ),

              // Selected Person Preview Card
              if (_selectedUserId != null) ...[
                const SizedBox(height: 8),
                Builder(
                  builder: (context) {
                    final u = db.users.where((user) => user.id == _selectedUserId).firstOrNull;
                    if (u == null) return const SizedBox.shrink();
                    final role = db.getUserRole(u);
                    final hasPhone = DocumentSharingService.cleanPhoneNumber(u.mobile).isNotEmpty;

                    return Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: AppRadius.smBorderRadius,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: AppColors.primary,
                            child: Text(
                              u.name.isNotEmpty ? u.name[0] : 'U',
                              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${u.name} • ${role.name}', style: AppTextStyles.bodyBold.copyWith(fontSize: 12)),
                                Text('Mobile: ${u.mobile} | Email: ${u.email}', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                          if (hasPhone)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF25D366).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.chat, size: 12, color: Color(0xFF128C7E)),
                                  SizedBox(width: 4),
                                  Text(
                                    'WhatsApp Ready',
                                    style: TextStyle(fontSize: 10, color: Color(0xFF128C7E), fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ],
              const SizedBox(height: 16),

              // 5. Target Delivery Date & Notes
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Target Delivery Date', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _deliveryDate,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) setState(() => _deliveryDate = picked);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: AppRadius.smBorderRadius,
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today, size: 16, color: AppColors.textMuted),
                                const SizedBox(width: 8),
                                Text(Formatters.formatDate(_deliveryDate), style: AppTextStyles.bodyMedium),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _notesCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Special Notes / Instructions (Optional)',
                  hintText: 'e.g. Expedite shortage for critical client installation...',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        ErpButton(
          text: 'Cancel',
          isOutlined: true,
          onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
        ),
        ErpButton(
          text: _isProcessing ? 'Processing...' : 'Convert to Sales Order',
          icon: _isProcessing ? null : Icons.check_circle_outline,
          isLoading: _isProcessing,
          onPressed: _isProcessing ? null : _handleConversion,
        ),
      ],
    );
  }

  Widget _buildSuccessView(
    BuildContext context,
    Sale so,
    AppUser user,
    MockDatabaseService db,
    List<ProductShortageDetail> shortages,
  ) {
    final role = db.getUserRole(user);
    final hasValidPhone = DocumentSharingService.cleanPhoneNumber(user.mobile).isNotEmpty;

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.lgBorderRadius),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      actionsPadding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.check_circle, color: AppColors.success, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sales Order Created Successfully!', style: AppTextStyles.h2.copyWith(fontSize: 17)),
                Text('Requirement recorded for ${_selectedAction.label} lead', style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
              ],
            ),
          ),
        ],
      ),
      content: Container(
        constraints: const BoxConstraints(maxWidth: 540),
        width: double.infinity,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Details summary card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: AppRadius.mdBorderRadius,
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Sales Order Number', style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
                            Text(so.invoiceNumber, style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary, fontSize: 14)),
                          ],
                        ),
                        ErpStatusBadge.success('SO GENERATED'),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Customer:', style: AppTextStyles.bodySmall),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            so.partyName,
                            style: AppTextStyles.bodyBold.copyWith(fontSize: 12),
                            textAlign: TextAlign.right,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Requirement Type:', style: AppTextStyles.bodySmall),
                        const SizedBox(width: 8),
                        Text(
                          _selectedAction.label,
                          style: TextStyle(
                            color: _selectedAction == ProductFulfillmentAction.purchase ? AppColors.purple : AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Responsible Person:', style: AppTextStyles.bodySmall),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${user.name} (${role.name})',
                            style: AppTextStyles.bodyBold.copyWith(fontSize: 12),
                            textAlign: TextAlign.right,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Notification Info Box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.08),
                  borderRadius: AppRadius.smBorderRadius,
                  border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.notifications_active_outlined, color: AppColors.info, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Notification recorded in ${_selectedAction.label} module for ${user.name} (${user.email}).',
                        style: AppTextStyles.bodySmall.copyWith(fontSize: 11.5, color: Colors.blue.shade900),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // WhatsApp Direct Action Box
              if (hasValidPhone)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366).withValues(alpha: 0.08),
                    borderRadius: AppRadius.smBorderRadius,
                    border: Border.all(color: const Color(0xFF25D366).withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.chat, color: Color(0xFF128C7E), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'WhatsApp Action (${user.name}: ${user.mobile})',
                              style: AppTextStyles.bodyBold.copyWith(color: const Color(0xFF128C7E), fontSize: 12.5),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Dispatch formatted ${_selectedAction.label} requisition directly to ${user.name}\'s mobile number.',
                        style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.send_rounded, size: 16),
                        label: Text('Open WhatsApp Requisition for ${user.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        onPressed: () => _sendWhatsAppNotification(so, user, db, shortages),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: AppRadius.smBorderRadius,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: AppColors.textMuted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'No mobile number registered for ${user.name}. WhatsApp notification skipped.',
                          style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
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
        ErpButton(
          text: 'View Sales Orders',
          icon: Icons.list_alt,
          onPressed: () {
            Navigator.of(context).pop();
            ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.salesOrders;
          },
        ),
      ],
    );
  }
}
