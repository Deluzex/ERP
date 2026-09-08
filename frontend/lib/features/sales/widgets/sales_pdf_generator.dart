import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../core/models/sale_model.dart';
import '../../../core/utils/file_downloader/file_downloader.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/erp_button.dart';
import '../../../shared/services/mock_database_service.dart';

class SalesPdfGeneratorDialog extends StatelessWidget {
  final Sale saleDoc;
  final MockDatabaseService db;
  final VoidCallback? onClose;

  const SalesPdfGeneratorDialog({
    super.key,
    required this.saleDoc,
    required this.db,
    this.onClose,
  });

  static Future<void> show(
    BuildContext context,
    Sale saleDoc,
    MockDatabaseService db, {
    VoidCallback? onClose,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => SalesPdfGeneratorDialog(
        saleDoc: saleDoc,
        db: db,
        onClose: onClose,
      ),
    );
  }

  String get _documentTitle {
    switch (saleDoc.documentType) {
      case SalesDocumentType.quotation:
        return 'QUOTATION';
      case SalesDocumentType.proformaInvoice:
        return 'PROFORMA INVOICE';
      case SalesDocumentType.salesOrder:
        return 'SALES ORDER CONFIRMATION';
      case SalesDocumentType.delivery:
        return 'DELIVERY CHALLAN / DISPATCH NOTE';
      case SalesDocumentType.invoice:
        return 'TAX INVOICE';
      case SalesDocumentType.salesReturn:
        return 'CREDIT NOTE / RETURN RECEIPT';
    }
  }

  String get _documentSubtitle {
    switch (saleDoc.documentType) {
      case SalesDocumentType.quotation:
        return saleDoc.revisionNumber > 0 ? 'Revision ${saleDoc.revisionNumber}' : 'Original Quotation';
      case SalesDocumentType.proformaInvoice:
        return '(Not a Tax Invoice - For Advance Payment)';
      case SalesDocumentType.salesOrder:
        return 'Order Processing & Stock Allocation';
      case SalesDocumentType.delivery:
        return 'Goods Transport & Delivery Acknowledgment';
      case SalesDocumentType.invoice:
        return 'Original for Recipient (GST Tax Invoice)';
      case SalesDocumentType.salesReturn:
        return 'Goods Return & Financial Credit Note';
    }
  }

  static String _cleanPdfText(String input) {
    return input
        .replaceAll('₹', 'Rs. ')
        .replaceAll('\u20B9', 'Rs. ')
        .replaceAll('Rs.  ', 'Rs. ');
  }

  static Future<Uint8List> generateDocumentPdfBytes(Sale saleDoc, MockDatabaseService db) async {
    final pdf = pw.Document();

    String customerCode = saleDoc.partyId;
    String customerPhone = saleDoc.customerMobile ?? '+91 98765 00000';
    String customerEmail = saleDoc.customerEmail ?? 'client@domain.com';
    String customerGst = saleDoc.customerGstNumber ?? '27AAACG9876K1Z1';
    String billingAddress = saleDoc.billingAddress ?? 'Plot 42, Industrial Area, Phase 2, Mumbai';
    String shippingAddress = saleDoc.shippingAddress ?? 'Site Location / Warehouse, Mumbai';

    if (saleDoc.partyType == PartyType.customer) {
      final cust = db.customers.where((c) => c.id == saleDoc.partyId).firstOrNull;
      if (cust != null) {
        customerCode = cust.id;
        customerPhone = cust.mobile.isNotEmpty ? cust.mobile : customerPhone;
        customerEmail = cust.email.isNotEmpty ? cust.email : customerEmail;
        customerGst = cust.gstNumber.isNotEmpty ? cust.gstNumber : customerGst;
        billingAddress = cust.address.isNotEmpty ? cust.address : billingAddress;
        shippingAddress = cust.address.isNotEmpty ? cust.address : shippingAddress;
      }
    } else if (saleDoc.partyType == PartyType.dealer) {
      final dlr = db.dealers.where((d) => d.id == saleDoc.partyId).firstOrNull;
      if (dlr != null) {
        customerCode = dlr.id;
        customerPhone = dlr.mobile.isNotEmpty ? dlr.mobile : customerPhone;
        customerEmail = dlr.email.isNotEmpty ? dlr.email : customerEmail;
        billingAddress = dlr.address.isNotEmpty ? dlr.address : billingAddress;
        shippingAddress = dlr.address.isNotEmpty ? dlr.address : shippingAddress;
      }
    } else if (saleDoc.partyType == PartyType.architect) {
      final arch = db.architects.where((a) => a.id == saleDoc.partyId).firstOrNull;
      if (arch != null) {
        customerCode = arch.id;
        customerPhone = arch.mobile.isNotEmpty ? arch.mobile : customerPhone;
        customerEmail = arch.email.isNotEmpty ? arch.email : customerEmail;
        customerGst = arch.gstNumber.isNotEmpty ? arch.gstNumber : customerGst;
        billingAddress = arch.address.isNotEmpty ? arch.address : billingAddress;
        shippingAddress = arch.address.isNotEmpty ? arch.address : shippingAddress;
      }
    }

    String docTitle;
    String docSub;
    switch (saleDoc.documentType) {
      case SalesDocumentType.quotation:
        docTitle = 'QUOTATION';
        docSub = saleDoc.revisionNumber > 0 ? 'Revision ${saleDoc.revisionNumber}' : 'Original Quotation';
        break;
      case SalesDocumentType.proformaInvoice:
        docTitle = 'PROFORMA INVOICE';
        docSub = '(Not a Tax Invoice - For Advance Payment)';
        break;
      case SalesDocumentType.salesOrder:
        docTitle = 'SALES ORDER CONFIRMATION';
        docSub = 'Order Processing & Stock Allocation';
        break;
      case SalesDocumentType.delivery:
        docTitle = 'DELIVERY CHALLAN / DISPATCH NOTE';
        docSub = 'Goods Transport & Delivery Acknowledgment';
        break;
      case SalesDocumentType.invoice:
        docTitle = 'TAX INVOICE';
        docSub = 'Original for Recipient (GST Tax Invoice)';
        break;
      case SalesDocumentType.salesReturn:
        docTitle = 'CREDIT NOTE / RETURN RECEIPT';
        docSub = 'Goods Return & Financial Credit Note';
        break;
    }

    final taxableAmount = saleDoc.taxableAmount;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        header: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'DELUZEX LIGHTING PVT. LTD.',
                        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text('Plot 88, Electronic Zone, SEEPZ, Andheri East, Mumbai - 400096', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
                      pw.Text('GSTIN: 27AABCD8899K1Z4 | Email: sales@deluzex.com | Web: www.deluzex.com', style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey400),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                      color: PdfColors.grey100,
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          docTitle,
                          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.black),
                        ),
                        pw.Text(docSub, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                        pw.Text('Doc No: ${saleDoc.invoiceNumber}', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                        pw.Text('Date: ${Formatters.formatDate(saleDoc.saleDate)}', style: const pw.TextStyle(fontSize: 8)),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Divider(thickness: 1, color: PdfColors.grey400),
              pw.SizedBox(height: 8),
            ],
          );
        },
        build: (pw.Context context) {
          return [
            // Client & Project Box
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('BILLED TO / CUSTOMER:', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                        pw.SizedBox(height: 2),
                        pw.Text('${saleDoc.partyName} ($customerCode)', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        pw.Text('Contact: ${saleDoc.customerContactPerson ?? "Procurement"} ($customerPhone)', style: const pw.TextStyle(fontSize: 8.5)),
                        pw.Text('Email: $customerEmail', style: const pw.TextStyle(fontSize: 8.5)),
                        pw.Text('GSTIN: $customerGst', style: const pw.TextStyle(fontSize: 8.5)),
                        pw.Text('Address: $billingAddress', style: const pw.TextStyle(fontSize: 8.5)),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('SHIPPING / SITE DETAILS:', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                        pw.SizedBox(height: 2),
                        if (saleDoc.projectName != null) pw.Text('Project: ${saleDoc.projectName}', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
                        if (saleDoc.architectName != null) pw.Text('Architect: ${saleDoc.architectName}', style: const pw.TextStyle(fontSize: 8.5)),
                        pw.Text('Shipping Address: $shippingAddress', style: const pw.TextStyle(fontSize: 8.5)),
                        if (saleDoc.vehicleNumber != null) pw.Text('Vehicle: ${saleDoc.vehicleNumber} | Driver: ${saleDoc.driverContact ?? "-"}', style: const pw.TextStyle(fontSize: 8.5)),
                        if (saleDoc.trackingNumber != null) pw.Text('LR / Tracking: ${saleDoc.trackingNumber}', style: const pw.TextStyle(fontSize: 8.5)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 12),

            // Line Items Table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.8),
              columnWidths: const {
                0: pw.FixedColumnWidth(24),
                1: pw.FlexColumnWidth(3),
                2: pw.FixedColumnWidth(50),
                3: pw.FixedColumnWidth(60),
                4: pw.FixedColumnWidth(50),
                5: pw.FixedColumnWidth(40),
                6: pw.FixedColumnWidth(70),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Sr', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Item Description', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold))),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Qty', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Rate', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Disc.', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('GST %', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
                    pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Total', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                  ],
                ),
                ...saleDoc.items.asMap().entries.map((entry) {
                  final idx = entry.key + 1;
                  final item = entry.value;
                  return pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('$idx', style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center)),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(item.finishedProductName, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                            pw.Text('[${item.finishedProductCode}] ${item.productDescription}', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
                          ],
                        ),
                      ),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('${item.quantity.toInt()} ${item.unit}', style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center)),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(_cleanPdfText(Formatters.formatCurrency(item.rate)), style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.right)),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(item.discountAmount > 0 ? _cleanPdfText(Formatters.formatCurrency(item.discountAmount)) : '-', style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.right)),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('${item.gstPercent.toInt()}%', style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center)),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(_cleanPdfText(Formatters.formatCurrency(item.lineTotal)), style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 12),

            // Totals & Terms
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  flex: 3,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (saleDoc.bankDetails != null) ...[
                        pw.Container(
                          padding: const pw.EdgeInsets.all(6),
                          decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('COMPANY BANK DETAILS FOR REMITTANCE:', style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                              pw.Text(saleDoc.bankDetails!, style: const pw.TextStyle(fontSize: 7.5)),
                            ],
                          ),
                        ),
                        pw.SizedBox(height: 6),
                      ],
                      pw.Text('TERMS AND CONDITIONS:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                      pw.Text(
                        saleDoc.termsAndConditions ?? '1. Taxes are calculated as applicable by GST regulations.\n2. Goods once delivered are subject to standard warranty terms.\n3. Payment is due as per agreed commercial milestones.',
                        style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(width: 16),
                pw.Expanded(
                  flex: 2,
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
                    child: pw.Column(
                      children: [
                        _buildPdfTotalRow('Subtotal', _cleanPdfText(Formatters.formatCurrency(saleDoc.subtotalAmount))),
                        if (saleDoc.discountAmount > 0) _buildPdfTotalRow('Discount', '- ${_cleanPdfText(Formatters.formatCurrency(saleDoc.discountAmount))}'),
                        _buildPdfTotalRow('Taxable Amount', _cleanPdfText(Formatters.formatCurrency(taxableAmount))),
                        _buildPdfTotalRow('CGST (${(saleDoc.items.isNotEmpty ? saleDoc.items.first.gstPercent / 2 : 9).toInt()}%)', _cleanPdfText(Formatters.formatCurrency(saleDoc.cgstAmount))),
                        _buildPdfTotalRow('SGST (${(saleDoc.items.isNotEmpty ? saleDoc.items.first.gstPercent / 2 : 9).toInt()}%)', _cleanPdfText(Formatters.formatCurrency(saleDoc.sgstAmount))),
                        if (saleDoc.igstAmount > 0) _buildPdfTotalRow('IGST', _cleanPdfText(Formatters.formatCurrency(saleDoc.igstAmount))),
                        pw.Divider(thickness: 0.8),
                        _buildPdfTotalRow('Grand Total', _cleanPdfText(Formatters.formatCurrency(saleDoc.totalAmount)), isBold: true),
                        if (saleDoc.paidAmount > 0) ...[
                          _buildPdfTotalRow('Received / Paid', _cleanPdfText(Formatters.formatCurrency(saleDoc.paidAmount))),
                          _buildPdfTotalRow('Balance Due', _cleanPdfText(Formatters.formatCurrency(saleDoc.pendingAmount)), isBold: true),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 24),

            // Signatures
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Customer Acceptance / Signature', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                    pw.SizedBox(height: 24),
                    pw.Container(width: 140, height: 0.8, color: PdfColors.grey500),
                    pw.Text('Authorized Signatory & Date', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('For Deluzex Architectural Luminaires Pvt. Ltd.', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 24),
                    pw.Container(width: 160, height: 0.8, color: PdfColors.grey500),
                    pw.Text('Authorized Signatory', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildPdfTotalRow(String label, String value, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 8, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text(value, style: pw.TextStyle(fontSize: 8.5, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String customerCode = saleDoc.partyId;
    String customerPhone = saleDoc.customerMobile ?? '+91 98765 00000';
    String customerEmail = saleDoc.customerEmail ?? 'client@domain.com';
    String customerGst = saleDoc.customerGstNumber ?? '27AAACG9876K1Z1';
    String billingAddress = saleDoc.billingAddress ?? 'Plot 42, Industrial Area, Phase 2, Mumbai';
    String shippingAddress = saleDoc.shippingAddress ?? 'Site Location / Warehouse, Mumbai';

    if (saleDoc.partyType == PartyType.customer) {
      final cust = db.customers.where((c) => c.id == saleDoc.partyId).firstOrNull;
      if (cust != null) {
        customerCode = cust.id;
        customerPhone = cust.mobile.isNotEmpty ? cust.mobile : customerPhone;
        customerEmail = cust.email.isNotEmpty ? cust.email : customerEmail;
        customerGst = cust.gstNumber.isNotEmpty ? cust.gstNumber : customerGst;
        billingAddress = cust.address.isNotEmpty ? cust.address : billingAddress;
        shippingAddress = cust.address.isNotEmpty ? cust.address : shippingAddress;
      }
    } else if (saleDoc.partyType == PartyType.dealer) {
      final dlr = db.dealers.where((d) => d.id == saleDoc.partyId).firstOrNull;
      if (dlr != null) {
        customerCode = dlr.id;
        customerPhone = dlr.mobile.isNotEmpty ? dlr.mobile : customerPhone;
        customerEmail = dlr.email.isNotEmpty ? dlr.email : customerEmail;
        billingAddress = dlr.address.isNotEmpty ? dlr.address : billingAddress;
        shippingAddress = dlr.address.isNotEmpty ? dlr.address : shippingAddress;
      }
    } else if (saleDoc.partyType == PartyType.architect) {
      final arch = db.architects.where((a) => a.id == saleDoc.partyId).firstOrNull;
      if (arch != null) {
        customerCode = arch.id;
        customerPhone = arch.mobile.isNotEmpty ? arch.mobile : customerPhone;
        customerEmail = arch.email.isNotEmpty ? arch.email : customerEmail;
        customerGst = arch.gstNumber.isNotEmpty ? arch.gstNumber : customerGst;
        billingAddress = arch.address.isNotEmpty ? arch.address : billingAddress;
        shippingAddress = arch.address.isNotEmpty ? arch.address : shippingAddress;
      }
    }

    final taxableAmount = saleDoc.taxableAmount;

    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.lgBorderRadius),
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      actionsPadding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: AppRadius.smBorderRadius,
                ),
                child: const Icon(Icons.picture_as_pdf, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$_documentTitle PDF Preview',
                    style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  Text(
                    'Document No: ${saleDoc.invoiceNumber} | Date: ${Formatters.formatDate(saleDoc.saleDate)}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () {
              Navigator.pop(context);
              if (onClose != null) onClose!();
            },
          ),
        ],
      ),
      content: SizedBox(
        width: 820,
        height: 600,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: AppRadius.mdBorderRadius,
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Header: Company Brand & Document Title
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Center(
                                child: Text(
                                  'd',
                                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 20),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'DELUZEX LIGHTING',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Deluzex Architectural Luminaires Pvt. Ltd.',
                          style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                        Text('Plot 88, Electronic Zone, SEEPZ, Andheri East, Mumbai - 400096', style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                        Text('GSTIN: 27AABCD8899K1Z4 | PAN: AABCD8899K', style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                        Text('Email: enterprise@deluzex.com | Web: www.deluzex.com', style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _documentTitle,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.sidebarBackground, letterSpacing: 1.0),
                          ),
                          Text(
                            _documentSubtitle,
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: saleDoc.documentType == SalesDocumentType.proformaInvoice ? AppColors.warningText : AppColors.primary),
                          ),
                          const SizedBox(height: 6),
                          Text('Doc No: ${saleDoc.invoiceNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87)),
                          Text('Date: ${Formatters.formatDate(saleDoc.saleDate)}', style: TextStyle(color: Colors.grey.shade700, fontSize: 11)),
                          if (saleDoc.validUntil != null)
                            Text('Valid Till: ${Formatters.formatDate(saleDoc.validUntil!)}', style: const TextStyle(color: AppColors.dangerText, fontWeight: FontWeight.bold, fontSize: 11)),
                          if (saleDoc.salesOrderNumber != null)
                            Text('SO Ref: ${saleDoc.salesOrderNumber}', style: TextStyle(color: Colors.grey.shade700, fontSize: 11)),
                          if (saleDoc.parentQuotationNumber != null)
                            Text('Quotation Ref: ${saleDoc.parentQuotationNumber}', style: TextStyle(color: Colors.grey.shade700, fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                Divider(color: Colors.grey.shade300, thickness: 1),
                const SizedBox(height: 12),

                // 2. Client & Project Details
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('BILLED TO / CUSTOMER:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey.shade600, letterSpacing: 0.5)),
                          const SizedBox(height: 4),
                          Text('${saleDoc.partyName} ($customerCode)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
                          Text('Contact: ${saleDoc.customerContactPerson ?? "Procurement Dept"} ($customerPhone)', style: TextStyle(color: Colors.grey.shade700, fontSize: 11)),
                          Text('Email: $customerEmail', style: TextStyle(color: Colors.grey.shade700, fontSize: 11)),
                          Text('GSTIN: $customerGst', style: TextStyle(color: Colors.grey.shade700, fontSize: 11)),
                          Text('Billing Address: $billingAddress', style: TextStyle(color: Colors.grey.shade700, fontSize: 11)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('SHIPPING / SITE & PROJECT DETAILS:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey.shade600, letterSpacing: 0.5)),
                          const SizedBox(height: 4),
                          if (saleDoc.projectName != null)
                            Text('Project: ${saleDoc.projectName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary)),
                          if (saleDoc.architectName != null)
                            Text('Architect: ${saleDoc.architectName}', style: TextStyle(color: Colors.grey.shade800, fontSize: 11)),
                          Text('Shipping Address: $shippingAddress', style: TextStyle(color: Colors.grey.shade700, fontSize: 11)),
                          if (saleDoc.vehicleNumber != null)
                            Text('Vehicle No: ${saleDoc.vehicleNumber} | Driver: ${saleDoc.driverContact ?? "-"}', style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 11)),
                          if (saleDoc.trackingNumber != null)
                            Text('LR / Tracking No: ${saleDoc.trackingNumber}', style: TextStyle(color: Colors.grey.shade700, fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // 3. Line Items Table
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Table(
                    columnWidths: const {
                      0: FixedColumnWidth(36),
                      1: FlexColumnWidth(2.5),
                      2: FixedColumnWidth(60),
                      3: FixedColumnWidth(80),
                      4: FixedColumnWidth(70),
                      5: FixedColumnWidth(60),
                      6: FixedColumnWidth(95),
                    },
                    children: [
                      TableRow(
                        decoration: BoxDecoration(color: Colors.grey.shade100),
                        children: [
                          _buildTableCell('Sr', isHeader: true),
                          _buildTableCell('Item Code & Description', isHeader: true),
                          _buildTableCell('Qty', isHeader: true, align: TextAlign.center),
                          _buildTableCell('Rate (₹)', isHeader: true, align: TextAlign.right),
                          _buildTableCell('Discount', isHeader: true, align: TextAlign.right),
                          _buildTableCell('GST %', isHeader: true, align: TextAlign.center),
                          _buildTableCell('Total (₹)', isHeader: true, align: TextAlign.right),
                        ],
                      ),
                      ...saleDoc.items.asMap().entries.map((entry) {
                        final idx = entry.key + 1;
                        final item = entry.value;
                        return TableRow(
                          decoration: BoxDecoration(
                            color: idx % 2 == 0 ? Colors.grey.shade50 : Colors.white,
                          ),
                          children: [
                            _buildTableCell('$idx', align: TextAlign.center),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.finishedProductName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87),
                                  ),
                                  Text(
                                    '[${item.finishedProductCode}] ${item.productDescription}',
                                    style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                            _buildTableCell('${item.quantity.toInt()} ${item.unit}', align: TextAlign.center),
                            _buildTableCell(Formatters.formatCurrency(item.rate).replaceAll('₹', ''), align: TextAlign.right),
                            _buildTableCell(item.discountAmount > 0 ? Formatters.formatCurrency(item.discountAmount).replaceAll('₹', '') : '-', align: TextAlign.right),
                            _buildTableCell('${item.gstPercent.toInt()}%', align: TextAlign.center),
                            _buildTableCell(Formatters.formatCurrency(item.lineTotal).replaceAll('₹', ''), align: TextAlign.right, isBold: true),
                          ],
                        );
                      }),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 4. Totals & Tax Calculation Breakdown
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (saleDoc.bankDetails != null) ...[
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('COMPANY BANK DETAILS FOR REMITTANCE:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10.5, color: Colors.black87)),
                                  const SizedBox(height: 2),
                                  Text(saleDoc.bankDetails!, style: TextStyle(color: Colors.grey.shade800, fontSize: 10.5)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                          Text('TERMS AND CONDITIONS:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey.shade700)),
                          const SizedBox(height: 4),
                          Text(
                            saleDoc.termsAndConditions ?? '1. Taxes are calculated as applicable by GST regulations.\n2. Goods once delivered are subject to Deluzex standard warranty policy.\n3. Payment is due as per agreed commercial milestones.',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 10.5, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          children: [
                            _buildTotalRow('Subtotal', Formatters.formatCurrency(saleDoc.subtotalAmount)),
                            if (saleDoc.discountAmount > 0)
                              _buildTotalRow('Discount', '- ${Formatters.formatCurrency(saleDoc.discountAmount)}', isDiscount: true),
                            _buildTotalRow('Taxable Amount', Formatters.formatCurrency(taxableAmount)),
                            _buildTotalRow('CGST (${(saleDoc.items.isNotEmpty ? saleDoc.items.first.gstPercent / 2 : 9).toInt()}%)', Formatters.formatCurrency(saleDoc.cgstAmount)),
                            _buildTotalRow('SGST (${(saleDoc.items.isNotEmpty ? saleDoc.items.first.gstPercent / 2 : 9).toInt()}%)', Formatters.formatCurrency(saleDoc.sgstAmount)),
                            if (saleDoc.igstAmount > 0)
                              _buildTotalRow('IGST', Formatters.formatCurrency(saleDoc.igstAmount)),
                            const Divider(),
                            _buildTotalRow('Grand Total', Formatters.formatCurrency(saleDoc.totalAmount), isGrandTotal: true),
                            if (saleDoc.paidAmount > 0) ...[
                              const SizedBox(height: 4),
                              _buildTotalRow('Received / Paid', Formatters.formatCurrency(saleDoc.paidAmount), color: AppColors.successText),
                              _buildTotalRow('Balance Due', Formatters.formatCurrency(saleDoc.pendingAmount), color: AppColors.dangerText, isBold: true),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // 5. Signatures & Footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Customer Acceptance / Signature', style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                        const SizedBox(height: 36),
                        Container(width: 180, height: 1, color: Colors.grey.shade400),
                        const SizedBox(height: 4),
                        Text('Authorized Signatory & Date', style: TextStyle(color: Colors.grey.shade500, fontSize: 10)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('For Deluzex Architectural Luminaires Pvt. Ltd.', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 11)),
                        const SizedBox(height: 36),
                        Container(width: 200, height: 1, color: Colors.grey.shade400),
                        const SizedBox(height: 4),
                        const Text('Authorized Signatory', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 10)),
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
          text: 'Copy PDF Link',
          icon: Icons.link,
          isOutlined: true,
          onPressed: () {
            Clipboard.setData(ClipboardData(text: 'https://erp.deluzex.com/docs/${saleDoc.invoiceNumber.replaceAll(RegExp(r"[/\\ ]"), "_")}.pdf'));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Document link copied to clipboard!'), backgroundColor: AppColors.success),
            );
          },
        ),
        ErpButton(
          text: 'Print',
          icon: Icons.print_outlined,
          isOutlined: true,
          onPressed: () async {
            try {
              final bytes = await generateDocumentPdfBytes(saleDoc, db);
              await Printing.layoutPdf(
                onLayout: (format) async => bytes,
                name: saleDoc.invoiceNumber,
              );
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Print error: $e'), backgroundColor: AppColors.danger),
                );
              }
            }
          },
        ),
        ErpButton(
          text: 'Download PDF',
          icon: Icons.download_outlined,
          onPressed: () async {
            try {
              final bytes = await generateDocumentPdfBytes(saleDoc, db);
              final safeFileName = saleDoc.invoiceNumber.replaceAll(RegExp(r'[/\\?%*:|"<> ]'), '_');
              await FileDownloader.downloadPdf(bytes, '$safeFileName.pdf');
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$safeFileName.pdf downloaded / saved!'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to generate PDF: $e'), backgroundColor: AppColors.danger),
                );
              }
            }
          },
        ),
      ],
    );
  }

  static Widget _buildTableCell(String text, {bool isHeader = false, TextAlign align = TextAlign.left, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontSize: isHeader ? 11 : 11.5,
          fontWeight: isHeader || isBold ? FontWeight.bold : FontWeight.normal,
          color: isHeader ? Colors.grey.shade800 : Colors.black87,
        ),
      ),
    );
  }

  static Widget _buildTotalRow(String label, String value, {bool isGrandTotal = false, bool isDiscount = false, Color? color, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isGrandTotal ? 13 : 11.5,
              fontWeight: isGrandTotal || isBold ? FontWeight.bold : FontWeight.w500,
              color: isGrandTotal ? Colors.black87 : Colors.grey.shade700,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isGrandTotal ? 14 : 12,
              fontWeight: isGrandTotal || isBold ? FontWeight.bold : FontWeight.w600,
              color: color ?? (isDiscount ? AppColors.dangerText : (isGrandTotal ? AppColors.primary : Colors.black87)),
            ),
          ),
        ],
      ),
    );
  }
}
