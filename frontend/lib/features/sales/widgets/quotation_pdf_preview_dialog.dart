import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../core/models/sale_model.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/erp_button.dart';
import '../../../shared/services/mock_database_service.dart';

class QuotationPdfPreviewDialog extends StatelessWidget {
  final Sale quotation;
  final MockDatabaseService db;
  final VoidCallback? onClose;

  const QuotationPdfPreviewDialog({
    super.key,
    required this.quotation,
    required this.db,
    this.onClose,
  });

  static Future<void> show(BuildContext context, Sale quotation, MockDatabaseService db, {VoidCallback? onClose}) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => QuotationPdfPreviewDialog(
        quotation: quotation,
        db: db,
        onClose: onClose,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Lookup customer or dealer details
    String customerCode = quotation.partyId;
    String customerPhone = '+91 98765 00000';
    String customerEmail = 'client@domain.com';
    String billingAddress = 'Plot 42, Industrial Area, Phase 2, Mumbai';
    String shippingAddress = 'Site Location / Warehouse, Mumbai';

    if (quotation.partyType == PartyType.customer) {
      final cust = db.customers.where((c) => c.id == quotation.partyId).firstOrNull;
      if (cust != null) {
        customerCode = cust.id;
        customerPhone = cust.mobile;
        customerEmail = cust.email;
        billingAddress = cust.address;
        shippingAddress = cust.address;
      }
    } else if (quotation.partyType == PartyType.dealer) {
      final dlr = db.dealers.where((d) => d.id == quotation.partyId).firstOrNull;
      if (dlr != null) {
        customerCode = dlr.id;
        customerPhone = dlr.mobile;
        customerEmail = dlr.email;
        billingAddress = dlr.address;
        shippingAddress = dlr.address;
      }
    } else if (quotation.partyType == PartyType.architect) {
      final arch = db.architects.where((a) => a.id == quotation.partyId).firstOrNull;
      if (arch != null) {
        customerCode = arch.id;
        customerPhone = arch.mobile;
        customerEmail = arch.email;
        billingAddress = arch.address;
        shippingAddress = arch.address;
      }
    }

    final taxableAmount = quotation.subtotalAmount - quotation.discountAmount;

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
                  const Text(
                    'Quotation PDF Preview',
                    style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  Text(
                    'Quotation No: ${quotation.invoiceNumber}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.black54),
            tooltip: 'Close',
            onPressed: () {
              Navigator.of(context).pop();
              if (onClose != null) onClose!();
            },
          ),
        ],
      ),
      content: SizedBox(
        width: 850,
        height: 580,
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade300, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Company Letterhead Header
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
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Center(
                                child: Text(
                                  'd',
                                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 22),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'DELUZEX LIGHTING PVT. LTD.',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87, letterSpacing: 0.5),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Borivali East, Mumbai, Maharashtra 400066',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                        ),
                        Text(
                          'Phone: +91 98765 43210 | Email: sales@deluzex.com',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                        ),
                        Text(
                          'GSTIN: 27AABCO8890K1Z9 | CIN: U31500MH2020PTC123456',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.primary),
                      ),
                      child: const Text(
                        'QUOTATION',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.black87, letterSpacing: 1.5),
                      ),
                    ),
                  ],
                ),
                const Divider(color: Colors.black87, thickness: 1.5, height: 28),

                // 2. Document Details & Metadata Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPdfMetaRow('Quotation Number:', quotation.invoiceNumber, isBold: true),
                        _buildPdfMetaRow('Quotation Date:', Formatters.formatDate(quotation.saleDate)),
                        if (quotation.validUntil != null)
                          _buildPdfMetaRow('Valid Until:', Formatters.formatDate(quotation.validUntil!)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _buildPdfMetaRow('Status:', (quotation.quotationStatus?.toString().split('.').last ?? 'Draft').toUpperCase()),
                        if (quotation.salesOrderNumber != null)
                          _buildPdfMetaRow('Sales Order Ref:', quotation.salesOrderNumber!),
                        if (quotation.projectName != null)
                          _buildPdfMetaRow('Project Scope:', quotation.projectName!),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 3. Customer & Address Section
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('CUSTOMER / BILL TO:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54)),
                            const SizedBox(height: 4),
                            Text(quotation.partyName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
                            Text('Code: $customerCode | Phone: $customerPhone', style: const TextStyle(fontSize: 10.5, color: Colors.black87)),
                            Text('Email: $customerEmail', style: const TextStyle(fontSize: 10.5, color: Colors.black87)),
                            Text('Address: $billingAddress', style: const TextStyle(fontSize: 10.5, color: Colors.black87)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('SHIPPING / DELIVERY DESTINATION:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54)),
                            const SizedBox(height: 4),
                            Text(quotation.partyName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
                            Text('Shipping Address: $shippingAddress', style: const TextStyle(fontSize: 10.5, color: Colors.black87)),
                            if (quotation.deliveryDate != null)
                              Text('Expected Dispatch: ${Formatters.formatDate(quotation.deliveryDate!)}', style: const TextStyle(fontSize: 10.5, color: Colors.black87)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 4. Product / Item Details Table
                Table(
                  border: TableBorder.all(color: Colors.grey.shade300, width: 1),
                  columnWidths: const {
                    0: FlexColumnWidth(0.8), // Sr No.
                    1: FlexColumnWidth(1.6), // SKU
                    2: FlexColumnWidth(3.0), // Description
                    3: FlexColumnWidth(1.2), // Qty
                    4: FlexColumnWidth(1.4), // Rate
                    5: FlexColumnWidth(1.2), // Discount
                    6: FlexColumnWidth(1.1), // Tax
                    7: FlexColumnWidth(1.8), // Amount
                  },
                  children: [
                    TableRow(
                      decoration: BoxDecoration(color: Colors.grey.shade200),
                      children: const [
                        Padding(padding: EdgeInsets.all(7), child: Text('Sr.', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                        Padding(padding: EdgeInsets.all(7), child: Text('Item Code', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold))),
                        Padding(padding: EdgeInsets.all(7), child: Text('Description', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold))),
                        Padding(padding: EdgeInsets.all(7), child: Text('Qty', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                        Padding(padding: EdgeInsets.all(7), child: Text('Rate (₹)', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                        Padding(padding: EdgeInsets.all(7), child: Text('Disc.', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                        Padding(padding: EdgeInsets.all(7), child: Text('GST %', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                        Padding(padding: EdgeInsets.all(7), child: Text('Amount (₹)', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                      ],
                    ),
                    ...List.generate(quotation.items.length, (idx) {
                      final item = quotation.items[idx];
                      return TableRow(
                        decoration: BoxDecoration(
                          color: idx % 2 == 0 ? Colors.white : Colors.grey.shade50,
                        ),
                        children: [
                          Padding(padding: const EdgeInsets.all(6.5), child: Text('${idx + 1}', style: const TextStyle(fontSize: 9.5), textAlign: TextAlign.center)),
                          Padding(padding: const EdgeInsets.all(6.5), child: Text(item.finishedProductCode, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600))),
                          Padding(padding: const EdgeInsets.all(6.5), child: Text(item.finishedProductName, style: const TextStyle(fontSize: 9.5))),
                          Padding(padding: const EdgeInsets.all(6.5), child: Text('${item.quantity.toInt()} ${item.unit}', style: const TextStyle(fontSize: 9.5), textAlign: TextAlign.right)),
                          Padding(padding: const EdgeInsets.all(6.5), child: Text(Formatters.formatCurrency(item.rate).replaceAll('₹', ''), style: const TextStyle(fontSize: 9.5), textAlign: TextAlign.right)),
                          Padding(padding: const EdgeInsets.all(6.5), child: Text(item.discountAmount > 0 ? Formatters.formatCurrency(item.discountAmount).replaceAll('₹', '') : '-', style: const TextStyle(fontSize: 9.5), textAlign: TextAlign.right)),
                          Padding(padding: const EdgeInsets.all(6.5), child: Text('${item.gstPercent.toInt()}%', style: const TextStyle(fontSize: 9.5), textAlign: TextAlign.right)),
                          Padding(padding: const EdgeInsets.all(6.5), child: Text(Formatters.formatCurrency(item.lineTotal).replaceAll('₹', ''), style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                        ],
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 18),

                // 5. Subtotal, Discounts, Taxes, Grand Total Summary
                Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: 320,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        children: [
                          _buildSummaryRow('Subtotal:', Formatters.formatCurrency(quotation.subtotalAmount)),
                          const SizedBox(height: 4),
                          _buildSummaryRow('Discount:', '- ${Formatters.formatCurrency(quotation.discountAmount)}'),
                          const SizedBox(height: 4),
                          _buildSummaryRow('Taxable Amount:', Formatters.formatCurrency(taxableAmount)),
                          const SizedBox(height: 4),
                          _buildSummaryRow('GST Tax (18%):', Formatters.formatCurrency(quotation.gstAmount)),
                          const Divider(height: 14, color: Colors.black45),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('GRAND TOTAL:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
                              Text(
                                Formatters.formatCurrency(quotation.totalAmount),
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 6. Payment Terms, Delivery Terms, Notes, Terms & Conditions
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    border: Border.all(color: Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('TERMS & CONDITIONS:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87)),
                      const SizedBox(height: 4),
                      const Text('1. Payment Terms: 30% advance with Purchase Order, 70% against delivery / dispatch.', style: TextStyle(fontSize: 9.5, color: Colors.black87)),
                      const Text('2. Delivery Terms: Ex-Factory / standard surface transport within 10-14 working days.', style: TextStyle(fontSize: 9.5, color: Colors.black87)),
                      const Text('3. Validity: Quotation prices are valid for 30 days from the date of issuance.', style: TextStyle(fontSize: 9.5, color: Colors.black87)),
                      const Text('4. Taxes: GST applicable as per prevailing government statutory rates.', style: TextStyle(fontSize: 9.5, color: Colors.black87)),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                // 7. Prepared By & Authorized Signatory Area
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Prepared By: Commercial Sales Desk', style: TextStyle(fontSize: 10, color: Colors.black87)),
                        const SizedBox(height: 32),
                        Container(width: 140, height: 1, color: Colors.grey.shade400),
                        const SizedBox(height: 4),
                        Text('Sales Representative', style: TextStyle(fontSize: 9, color: Colors.grey.shade600)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('For DELUZEX LIGHTING PVT. LTD.', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87)),
                        const SizedBox(height: 32),
                        Container(width: 140, height: 1, color: Colors.grey.shade400),
                        const SizedBox(height: 4),
                        Text('Authorized Signatory', style: TextStyle(fontSize: 9, color: Colors.grey.shade600)),
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
        // Share Action
        ErpButton(
          text: 'Share',
          icon: Icons.share_outlined,
          isOutlined: true,
          onPressed: () {
            Clipboard.setData(ClipboardData(
              text: 'https://erp.deluzex.com/quotations/${quotation.id}/preview?no=${quotation.invoiceNumber}',
            ));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Quotation link for ${quotation.invoiceNumber} copied to clipboard!'),
                backgroundColor: AppColors.success,
              ),
            );
          },
        ),

        // Download Action
        ErpButton(
          text: 'Download',
          icon: Icons.download_outlined,
          isOutlined: true,
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Quotation ${quotation.invoiceNumber}.pdf downloaded successfully!'),
                backgroundColor: AppColors.success,
              ),
            );
          },
        ),

        // Print Action
        ErpButton(
          text: 'Print',
          icon: Icons.print_outlined,
          isOutlined: true,
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Sent Quotation ${quotation.invoiceNumber} to system printer.'),
                backgroundColor: AppColors.info,
              ),
            );
          },
        ),

        // Close Action
        ErpButton(
          text: 'Close',
          onPressed: () {
            Navigator.of(context).pop();
            if (onClose != null) onClose!();
          },
        ),
      ],
    );
  }

  Widget _buildPdfMetaRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 10.5, color: Colors.black54)),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 10.5, color: Colors.black54)),
        Text(value, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.black87)),
      ],
    );
  }
}
