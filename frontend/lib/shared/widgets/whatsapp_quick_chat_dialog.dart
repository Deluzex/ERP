import '../../core/widgets/erp_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radius.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/models/whatsapp_models.dart';
import '../../core/utils/document_sharing_service.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/id_generator.dart';
import '../../core/widgets/erp_button.dart';
import '../providers/app_state_providers.dart';

enum QuickWhatsAppTemplate {
  quotationSent,
  orderConfirmation,
  paymentReminder,
  dispatchInfo,
  deliveryUpdate,
  projectUpdate,
  customMessage,
}

class WhatsAppQuickChatDialog extends ConsumerStatefulWidget {
  final String recipientName;
  final String recipientNumber;
  final String? partyRole; // Customer, Dealer, Architect, Vendor
  final String? relatedEntityType;
  final String? relatedEntityId;
  final String? relatedEntityNumber;
  final QuickWhatsAppTemplate? initialTemplate;
  final double? pendingAmount;
  final double? saleTotal;
  final double? paidAmount;
  final int? pendingDays;
  final DateTime? oldestInvoiceDate;

  const WhatsAppQuickChatDialog({
    super.key,
    required this.recipientName,
    required this.recipientNumber,
    this.partyRole,
    this.relatedEntityType,
    this.relatedEntityId,
    this.relatedEntityNumber,
    this.initialTemplate,
    this.pendingAmount,
    this.saleTotal,
    this.paidAmount,
    this.pendingDays,
    this.oldestInvoiceDate,
  });

  static void show(
    BuildContext context, {
    required String recipientName,
    required String recipientNumber,
    String? partyRole,
    String? relatedEntityType,
    String? relatedEntityId,
    String? relatedEntityNumber,
    QuickWhatsAppTemplate? initialTemplate,
    double? pendingAmount,
    double? saleTotal,
    double? paidAmount,
    int? pendingDays,
    DateTime? oldestInvoiceDate,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => WhatsAppQuickChatDialog(
        recipientName: recipientName,
        recipientNumber: recipientNumber,
        partyRole: partyRole,
        relatedEntityType: relatedEntityType,
        relatedEntityId: relatedEntityId,
        relatedEntityNumber: relatedEntityNumber,
        initialTemplate: initialTemplate,
        pendingAmount: pendingAmount,
        saleTotal: saleTotal,
        paidAmount: paidAmount,
        pendingDays: pendingDays,
        oldestInvoiceDate: oldestInvoiceDate,
      ),
    );
  }

  static void showCustomerQuickChat(
    BuildContext context, {
    required String customerName,
    required String customerPhone,
    String? docNumber,
    String? projectName,
    double? pendingAmount,
    double? saleTotal,
    double? paidAmount,
    int? pendingDays,
    DateTime? oldestInvoiceDate,
    QuickWhatsAppTemplate? initialTemplate,
  }) {
    final hasPending = (pendingAmount != null && pendingAmount > 0);
    show(
      context,
      recipientName: customerName,
      recipientNumber: customerPhone,
      partyRole: 'Customer',
      relatedEntityType: projectName != null ? 'Project' : (docNumber != null ? 'Document' : null),
      relatedEntityNumber: docNumber ?? projectName,
      initialTemplate: initialTemplate ?? (hasPending ? QuickWhatsAppTemplate.paymentReminder : QuickWhatsAppTemplate.customMessage),
      pendingAmount: pendingAmount,
      saleTotal: saleTotal,
      paidAmount: paidAmount,
      pendingDays: pendingDays,
      oldestInvoiceDate: oldestInvoiceDate,
    );
  }

  static void showCustomerPaymentReminder(
    BuildContext context, {
    required String customerName,
    required String customerPhone,
    required double pendingAmount,
    double? saleTotal,
    double? paidAmount,
    int? pendingDays,
    DateTime? oldestInvoiceDate,
    String? docNumber,
  }) {
    showCustomerQuickChat(
      context,
      customerName: customerName,
      customerPhone: customerPhone,
      docNumber: docNumber,
      pendingAmount: pendingAmount,
      saleTotal: saleTotal,
      paidAmount: paidAmount,
      pendingDays: pendingDays,
      oldestInvoiceDate: oldestInvoiceDate,
      initialTemplate: QuickWhatsAppTemplate.paymentReminder,
    );
  }

  static void showArchitectQuickChat(
    BuildContext context, {
    required String architectName,
    required String architectPhone,
    String? firmName,
    String? projectName,
    String? commissionNumber,
  }) {
    show(
      context,
      recipientName: architectName,
      recipientNumber: architectPhone,
      partyRole: 'Architect',
      relatedEntityType: 'Architect Commission',
      relatedEntityNumber: commissionNumber ?? projectName,
    );
  }

  @override
  ConsumerState<WhatsAppQuickChatDialog> createState() => _WhatsAppQuickChatDialogState();
}

class _WhatsAppQuickChatDialogState extends ConsumerState<WhatsAppQuickChatDialog> {
  late TextEditingController _phoneCtrl;
  late TextEditingController _messageCtrl;
  late QuickWhatsAppTemplate _selectedTemplate;

  @override
  void initState() {
    super.initState();
    _phoneCtrl = TextEditingController(text: widget.recipientNumber);
    _messageCtrl = TextEditingController();
    _selectedTemplate = widget.initialTemplate ??
        ((widget.pendingAmount != null && widget.pendingAmount! > 0)
            ? QuickWhatsAppTemplate.paymentReminder
            : QuickWhatsAppTemplate.customMessage);
    _applyTemplate(_selectedTemplate);
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  String _formatDurationEnglish(int? days) {
    if (days == null || days <= 0) return 'recent days';
    if (days >= 30) {
      final months = (days / 30).floor();
      if (months == 1) return '1 month ($days days)';
      return '$months months ($days days)';
    }
    return '$days days';
  }

  void _applyTemplate(QuickWhatsAppTemplate template) {
    final name = widget.recipientName;
    final docNum = widget.relatedEntityNumber ?? 'DOC-2026';

    switch (template) {
      case QuickWhatsAppTemplate.paymentReminder:
        if (widget.pendingAmount != null && widget.pendingAmount! > 0) {
          final pendingStr = Formatters.formatCurrency(widget.pendingAmount!);
          final saleStr = widget.saleTotal != null ? Formatters.formatCurrency(widget.saleTotal!) : null;
          final paidStr = widget.paidAmount != null ? Formatters.formatCurrency(widget.paidAmount!) : null;
          final durationEng = _formatDurationEnglish(widget.pendingDays);
          final dateStr = widget.oldestInvoiceDate != null
              ? DateFormat('dd MMM yyyy').format(widget.oldestInvoiceDate!)
              : null;

          _messageCtrl.text = '''Dear $name,

Greetings from Deluzex Lighting Systems.

This is a gentle reminder that your payment of $pendingStr has been pending for $durationEng${dateStr != null ? ' (since $dateStr)' : ''}.

📊 Account Summary:
${saleStr != null ? '• Total Billed: $saleStr\n' : ''}${paidStr != null ? '• Amount Paid: $paidStr\n' : ''}• Outstanding Balance: $pendingStr

Kindly arrange the payment remittance at your earliest convenience. If already settled, please share the payment confirmation/reference.

Thank you!
Deluzex Accounts & Billing Team
📞 +91 98250 12345''';
        } else {
          _messageCtrl.text = '''Dear $name,

This is a friendly reminder regarding the pending milestone payment for Invoice $docNum.

Kindly arrange the remittance as per agreed terms. Thank you for your continued partnership!

_Deluzex Accounts Desk_''';
        }
        break;

      case QuickWhatsAppTemplate.quotationSent:
        _messageCtrl.text = '''Hello $name,

We have prepared and issued the official quotation ($docNum) for your architectural lighting requirements.

Kindly review the specifications, quantities, and pricing. Please let us know if you need any adjustments or finish samples.

_Deluzex Lighting Systems_''';
        break;

      case QuickWhatsAppTemplate.orderConfirmation:
        _messageCtrl.text = '''Hello $name,

Your order confirmation ($docNum) has been successfully verified and moved to our assembly & testing line.

We will keep you updated as milestone production and QC checks progress.

_Deluzex Order Fulfillment Desk_''';
        break;

      case QuickWhatsAppTemplate.dispatchInfo:
        _messageCtrl.text = '''Hello $name,

Your materials for $docNum have been packed and dispatched via our logistics partner. 

Tracking details and delivery challan are available. Consignment is scheduled for delivery shortly.

_Deluzex Logistics Team_''';
        break;

      case QuickWhatsAppTemplate.deliveryUpdate:
        _messageCtrl.text = '''Dear $name,

Our delivery team has delivered the material consignment ($docNum) to your designated site location.

Kindly verify the packages and share the signed delivery endorsement copy.

_Deluzex Dispatch Team_''';
        break;

      case QuickWhatsAppTemplate.projectUpdate:
        _messageCtrl.text = '''Dear $name,

Here is a quick milestone update regarding project $docNum. All architectural luminaire profiles have been calibrated and are on schedule.

Please feel free to connect for any drawing revisions or site inspections.

_Deluzex Architectural Project Desk_''';
        break;

      case QuickWhatsAppTemplate.customMessage:
        _messageCtrl.text = '''Dear $name,

Greetings from Deluzex Lighting Systems.

''';
        break;
    }
  }

  void _sendMessage() {
    final phone = _phoneCtrl.text.trim();
    final msg = _messageCtrl.text.trim();
    if (phone.isEmpty || msg.isEmpty) return;

    final db = ref.read(databaseServiceProvider);
    db.logWhatsAppMessage(WhatsAppMessageLog(
      id: IdGenerator.generateId('WLOG'),
      messageType: _selectedTemplate.name.toUpperCase(),
      recipientName: widget.recipientName,
      recipientNumber: phone,
      relatedEntityType: widget.relatedEntityType ?? widget.partyRole,
      relatedEntityId: widget.relatedEntityId,
      relatedEntityNumber: widget.relatedEntityNumber,
      messageText: msg,
      sentAt: DateTime.now(),
      status: 'Sent',
    ));

    DocumentSharingService.shareToWhatsApp(
      phoneNumber: phone,
      message: msg,
    );

    Navigator.pop(context);
ErpToast.showInfo(context, 'Opening WhatsApp with message for ${widget.recipientName}...');
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 450;
    final hasPending = widget.pendingAmount != null && widget.pendingAmount! > 0;

    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.lgBorderRadius),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 580),
        width: double.infinity,
        padding: EdgeInsets.all(isCompact ? 16 : 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
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
                            color: const Color(0xFF25D366).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.chat_outlined, color: Color(0xFF25D366), size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Quick WhatsApp Communication', style: AppTextStyles.h2),
                              const SizedBox(height: 2),
                              Text('${widget.recipientName} ${widget.partyRole != null ? "(${widget.partyRole})" : ""}', style: AppTextStyles.bodySmall),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Divider(height: 1),
              const SizedBox(height: 14),

              // Pending Payment Reminder Alert Banner
              if (hasPending) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFF59E0B)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.alarm_on_rounded, color: Color(0xFFB45309), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Pending Payment Reminder: ${Formatters.formatCurrency(widget.pendingAmount!)} (${_formatDurationEnglish(widget.pendingDays)})',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF92400E),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Recipient Phone
              TextFormField(
                controller: _phoneCtrl,
                decoration: const InputDecoration(
                  labelText: 'Recipient WhatsApp Number *',
                  prefixIcon: Icon(Icons.phone, size: 18),
                ),
              ),
              const SizedBox(height: 14),

              // Template Selector
              Text('Select Message Template', style: AppTextStyles.bodyBold.copyWith(fontSize: 12)),
              const SizedBox(height: 6),
              DropdownButtonFormField<QuickWhatsAppTemplate>(
                initialValue: _selectedTemplate,
                isExpanded: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.quickreply_outlined, size: 18),
                ),
                items: const [
                  DropdownMenuItem(value: QuickWhatsAppTemplate.paymentReminder, child: Text('🔔 Payment Reminder', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: QuickWhatsAppTemplate.quotationSent, child: Text('📄 Quotation Sent', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: QuickWhatsAppTemplate.orderConfirmation, child: Text('✅ Order Confirmation', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: QuickWhatsAppTemplate.dispatchInfo, child: Text('🚚 Dispatch & Tracking Info', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: QuickWhatsAppTemplate.deliveryUpdate, child: Text('📦 Delivery Confirmation', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: QuickWhatsAppTemplate.projectUpdate, child: Text('📐 Project Progress Update', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: QuickWhatsAppTemplate.customMessage, child: Text('✍️ Custom Message', overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedTemplate = val;
                      _applyTemplate(val);
                    });
                  }
                },
              ),
              const SizedBox(height: 14),

              // Message Body
              Text('Message Content (Editable)', style: AppTextStyles.bodyBold.copyWith(fontSize: 12)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _messageCtrl,
                maxLines: 7,
                style: const TextStyle(fontSize: 12.5),
                decoration: const InputDecoration(
                  hintText: 'Type your message...',
                ),
              ),
              const SizedBox(height: 20),

              // Buttons
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 10,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.copy_outlined, size: 16),
                    label: const Text('Copy Text'),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _messageCtrl.text.trim()));
ErpToast.showInfo(context, 'Message copied to clipboard!');
                    },
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ErpButton(
                        text: 'Cancel',
                        isOutlined: true,
                        onPressed: () => Navigator.pop(context),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.send, size: 16),
                        label: const Text('Send on WhatsApp', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: _sendMessage,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
