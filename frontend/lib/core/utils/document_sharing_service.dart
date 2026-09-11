import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

enum SharePlatform {
  whatsApp,
  whatsAppBusiness,
  email,
  facebook,
  instagram,
  nativeShare,
  copyLink,
  downloadPdf,
}

class DocumentSharingService {
  DocumentSharingService._();

  static String cleanPhoneNumber(String input) {
    var cleaned = input.replaceAll(RegExp(r'[^0-9+]'), '');
    if (!cleaned.startsWith('+') && cleaned.length == 10) {
      cleaned = '91$cleaned';
    } else if (cleaned.startsWith('+')) {
      cleaned = cleaned.substring(1);
    }
    return cleaned;
  }

  static void openUrl(String url) {
    if (kIsWeb) {
      try {
        html.window.open(url, '_blank');
      } catch (e) {
        debugPrint('Error opening URL on web: $e');
      }
    } else {
      debugPrint('Launch URL: $url');
    }
  }

  static void shareToWhatsApp({
    required String phoneNumber,
    required String message,
    bool isBusiness = false,
  }) {
    final cleaned = cleanPhoneNumber(phoneNumber);
    final encoded = Uri.encodeComponent(message);
    final url = cleaned.isNotEmpty
        ? 'https://wa.me/$cleaned?text=$encoded'
        : 'https://api.whatsapp.com/send?text=$encoded';
    openUrl(url);
  }

  static void shareViaEmail({
    required String recipientEmail,
    required String subject,
    required String body,
  }) {
    final encodedSub = Uri.encodeComponent(subject);
    final encodedBody = Uri.encodeComponent(body);
    final url = 'mailto:$recipientEmail?subject=$encodedSub&body=$encodedBody';
    openUrl(url);
  }

  static void shareToFacebook({
    required String shareUrl,
    required String quote,
  }) {
    final encodedUrl = Uri.encodeComponent(shareUrl);
    final encodedQuote = Uri.encodeComponent(quote);
    final url = 'https://www.facebook.com/sharer/sharer.php?u=$encodedUrl&quote=$encodedQuote';
    openUrl(url);
  }

  static void shareToInstagram({
    required String message,
  }) {
    Clipboard.setData(ClipboardData(text: message));
    openUrl('https://www.instagram.com/');
  }

  static String buildQuotationShareMessage({
    required String quotationNumber,
    required String partyName,
    required double totalAmount,
    required String projectName,
    required String validDate,
  }) {
    return '''✨ *QUOTATION FROM DELUZEX LIGHTING* ✨
-------------------------------------
*Quotation No:* $quotationNumber
*Client:* $partyName
*Project:* $projectName
*Total Amount:* ₹${totalAmount.toStringAsFixed(2)}
*Valid Until:* $validDate

Dear $partyName,
Thank you for your interest in Deluzex architectural fixtures. Please review the attached quotation and specifications.

📄 Download Quotation PDF:
https://erp.deluzex.com/docs/$quotationNumber.pdf

For queries, reply directly to this message or call our design desk.
_Deluzex Lighting Systems - Elevating Luxury Spaces_''';
  }

  static String buildInvoiceShareMessage({
    required String invoiceNumber,
    required String partyName,
    required double totalAmount,
    required double pendingAmount,
    required String invoiceDate,
  }) {
    return '''🧾 *TAX INVOICE FROM DELUZEX LIGHTING* 🧾
-------------------------------------
*Invoice No:* $invoiceNumber
*Billed To:* $partyName
*Invoice Date:* $invoiceDate
*Total Amount:* ₹${totalAmount.toStringAsFixed(2)}
*Balance Due:* ₹${pendingAmount.toStringAsFixed(2)}

Dear $partyName,
Please find your official Tax Invoice for materials supplied by Deluzex.

📄 Download Invoice PDF:
https://erp.deluzex.com/invoices/$invoiceNumber.pdf

Kindly process the outstanding milestone remittance as per agreed terms.
_Deluzex Lighting Systems_''';
  }

  static String buildDeliveryShareMessage({
    required String challanNumber,
    required String partyName,
    required String vehicleNumber,
    required String courierName,
    required String trackingNumber,
    required String expectedDate,
  }) {
    return '''🚚 *DISPATCH & DELIVERY UPDATE* 🚚
-------------------------------------
*Delivery Challan:* $challanNumber
*Customer:* $partyName
*Courier / Transport:* $courierName
*LR / Tracking No:* $trackingNumber
*Vehicle No:* $vehicleNumber
*Expected Delivery:* $expectedDate

Your ordered architectural lighting consignment is en route. 

📄 View Delivery Challan:
https://erp.deluzex.com/dispatch/$challanNumber.pdf

_Deluzex Logistics Desk_''';
  }

  static String buildPaymentReminderMessage({
    required String partyName,
    required String invoiceNumber,
    required double pendingAmount,
    required String dueDate,
  }) {
    return '''🔔 *PAYMENT REMINDER - DELUZEX* 🔔
-------------------------------------
*Dear $partyName,*
This is a gentle reminder regarding the outstanding balance for Invoice *$invoiceNumber*.

*Pending Amount:* ₹${pendingAmount.toStringAsFixed(2)}
*Due Date:* $dueDate

Bank Details for NEFT/RTGS:
• Bank: HDFC Bank Ltd
• A/C No: 50200049281144
• IFSC: HDFC0000060

Please share transaction remittance reference once processed. Thank you!''';
  }

  static String buildLowStockAlertMessage({
    required String itemName,
    required String itemCode,
    required String itemType,
    required double currentStock,
    required double minStock,
    required double reorderLevel,
    required String unit,
  }) {
    return '''⚠️ *LOW STOCK PRODUCTION ALERT* ⚠️
-------------------------------------
*$itemType is running critically low!*
• *Item:* $itemName
• *Code:* $itemCode
• *Current Stock:* $currentStock $unit
• *Minimum Stock:* $minStock $unit
• *Reorder Level:* $reorderLevel $unit

⚡ *Impact:* This stock deficit may delay active production orders. Please arrange immediate purchase / requisition.
_Deluzex Production & Inventory Control_''';
  }
}
