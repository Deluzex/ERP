import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../app/theme/app_radius.dart';
import '../../core/models/sale_model.dart';
import '../../core/models/whatsapp_models.dart';
import '../../core/utils/document_sharing_service.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/id_generator.dart';
import '../../core/widgets/erp_button.dart';
import '../providers/app_state_providers.dart';

class ShareDocumentDialog extends ConsumerStatefulWidget {
  final Sale saleDoc;
  final VoidCallback? onDownloadPdf;

  const ShareDocumentDialog({
    super.key,
    required this.saleDoc,
    this.onDownloadPdf,
  });

  static void show(BuildContext context, Sale doc, {VoidCallback? onDownloadPdf}) {
    showDialog(
      context: context,
      builder: (ctx) => ShareDocumentDialog(
        saleDoc: doc,
        onDownloadPdf: onDownloadPdf,
      ),
    );
  }

  @override
  ConsumerState<ShareDocumentDialog> createState() => _ShareDocumentDialogState();
}

class _ShareDocumentDialogState extends ConsumerState<ShareDocumentDialog> {
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _messageCtrl;

  @override
  void initState() {
    super.initState();
    final doc = widget.saleDoc;
    _phoneCtrl = TextEditingController(text: doc.customerMobile ?? '+91 98200 12345');
    _emailCtrl = TextEditingController(text: doc.customerEmail ?? 'client@oberoigroup.com');

    String initialMsg;
    if (doc.documentType == SalesDocumentType.quotation) {
      initialMsg = DocumentSharingService.buildQuotationShareMessage(
        quotationNumber: doc.invoiceNumber,
        partyName: doc.partyName,
        totalAmount: doc.totalAmount,
        projectName: doc.projectName ?? 'Architectural Fixtures Scope',
        validDate: doc.validUntil != null ? Formatters.formatDate(doc.validUntil!) : '30 Days',
      );
    } else if (doc.documentType == SalesDocumentType.delivery) {
      initialMsg = DocumentSharingService.buildDeliveryShareMessage(
        challanNumber: doc.invoiceNumber,
        partyName: doc.partyName,
        vehicleNumber: doc.vehicleNumber ?? 'MH-04-AZ-8812',
        courierName: doc.courierName ?? 'BlueDart Express',
        trackingNumber: doc.trackingNumber ?? 'BDX-990214',
        expectedDate: doc.expectedDeliveryDate != null ? Formatters.formatDate(doc.expectedDeliveryDate!) : '1-2 Business Days',
      );
    } else {
      initialMsg = DocumentSharingService.buildInvoiceShareMessage(
        invoiceNumber: doc.invoiceNumber,
        partyName: doc.partyName,
        totalAmount: doc.totalAmount,
        pendingAmount: doc.pendingAmount,
        invoiceDate: Formatters.formatDate(doc.saleDate),
      );
    }
    _messageCtrl = TextEditingController(text: initialMsg);
  }

  @override
  void dispose() {
    _phoneCtrl.dispose;
    _emailCtrl.dispose;
    _messageCtrl.dispose();
    super.dispose();
  }

  void _logShareAction(String platform) {
    final db = ref.read(databaseServiceProvider);
    db.logWhatsAppMessage(WhatsAppMessageLog(
      id: IdGenerator.generateId('WLOG'),
      messageType: '${widget.saleDoc.documentType.name.toUpperCase()} Shared ($platform)',
      recipientName: widget.saleDoc.partyName,
      recipientNumber: _phoneCtrl.text.trim(),
      relatedEntityType: widget.saleDoc.documentType.name,
      relatedEntityId: widget.saleDoc.id,
      relatedEntityNumber: widget.saleDoc.invoiceNumber,
      messageText: _messageCtrl.text.trim(),
      sentAt: DateTime.now(),
      status: 'Sent',
    ));
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.saleDoc;

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.lgBorderRadius),
      child: Container(
        width: 620,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.share_outlined, color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Direct Document Sharing', style: AppTextStyles.h2),
                          const SizedBox(height: 2),
                          Text('${doc.documentType.name.toUpperCase()}: ${doc.invoiceNumber} • ${doc.partyName}', style: AppTextStyles.bodySmall),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // Contact Numbers
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _phoneCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Recipient WhatsApp / Mobile *',
                        prefixIcon: Icon(Icons.phone_android, size: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _emailCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Recipient Email Address',
                        prefixIcon: Icon(Icons.email_outlined, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Pre-filled Message Text
              Text('Message Preview (Editable)', style: AppTextStyles.bodyBold.copyWith(fontSize: 12)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _messageCtrl,
                maxLines: 7,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                decoration: const InputDecoration(
                  hintText: 'Enter document sharing message...',
                ),
              ),
              const SizedBox(height: 18),

              // Platform Buttons
              Text('Select Sharing Channel', style: AppTextStyles.bodyBold.copyWith(fontSize: 12)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  // WhatsApp
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.chat, size: 18),
                    label: const Text('WhatsApp Direct', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    onPressed: () {
                      _logShareAction('WhatsApp');
                      DocumentSharingService.shareToWhatsApp(
                        phoneNumber: _phoneCtrl.text.trim(),
                        message: _messageCtrl.text.trim(),
                      );
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Opening WhatsApp with pre-filled document details...'), backgroundColor: Color(0xFF25D366)),
                      );
                    },
                  ),

                  // WhatsApp Business
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF128C7E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.business_center_outlined, size: 18),
                    label: const Text('WhatsApp Business', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    onPressed: () {
                      _logShareAction('WhatsApp Business');
                      DocumentSharingService.shareToWhatsApp(
                        phoneNumber: _phoneCtrl.text.trim(),
                        message: _messageCtrl.text.trim(),
                        isBusiness: true,
                      );
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Opening WhatsApp Business...'), backgroundColor: Color(0xFF128C7E)),
                      );
                    },
                  ),

                  // Email
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.email_outlined, size: 18),
                    label: const Text('Email Client', style: TextStyle(fontSize: 12)),
                    onPressed: () {
                      _logShareAction('Email');
                      DocumentSharingService.shareViaEmail(
                        recipientEmail: _emailCtrl.text.trim(),
                        subject: 'Deluzex Lighting: ${doc.documentType.name.toUpperCase()} - ${doc.invoiceNumber}',
                        body: _messageCtrl.text.trim(),
                      );
                      Navigator.pop(context);
                    },
                  ),

                  // Facebook
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1877F2),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.facebook, size: 18),
                    label: const Text('Facebook', style: TextStyle(fontSize: 12)),
                    onPressed: () {
                      _logShareAction('Facebook');
                      DocumentSharingService.shareToFacebook(
                        shareUrl: 'https://erp.deluzex.com/docs/${doc.invoiceNumber}.pdf',
                        quote: _messageCtrl.text.trim(),
                      );
                    },
                  ),

                  // Instagram
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFE4405F),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.camera_alt_outlined, size: 18),
                    label: const Text('Instagram / Copy', style: TextStyle(fontSize: 12)),
                    onPressed: () {
                      _logShareAction('Instagram');
                      DocumentSharingService.shareToInstagram(message: _messageCtrl.text.trim());
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Text copied to clipboard! Opening Instagram...')),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 14),

              // Action Bar Fallbacks
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.copy_outlined, size: 16),
                    label: const Text('Copy Message Text'),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _messageCtrl.text.trim()));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Message copied to clipboard!')),
                      );
                    },
                  ),
                  Row(
                    children: [
                      if (widget.onDownloadPdf != null) ...[
                        ErpButton(
                          text: 'Download PDF',
                          icon: Icons.download,
                          isOutlined: true,
                          onPressed: () {
                            Navigator.pop(context);
                            widget.onDownloadPdf!();
                          },
                        ),
                        const SizedBox(width: 8),
                      ],
                      ErpButton(
                        text: 'Done',
                        onPressed: () => Navigator.pop(context),
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
