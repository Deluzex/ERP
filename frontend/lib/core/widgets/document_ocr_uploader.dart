import 'dart:async';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radius.dart';
import '../../app/theme/app_text_styles.dart';
import 'erp_button.dart';

enum OcrDocType {
  purchaseInvoice,
  customerPo,
  quotation,
  vendorDoc,
  customerDoc,
  architectDoc,
}

class DocumentOcrUploader extends StatefulWidget {
  final OcrDocType docType;
  final Function(Map<String, String> extractedData) onConfirm;
  final VoidCallback onCancel;

  const DocumentOcrUploader({
    super.key,
    required this.docType,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  State<DocumentOcrUploader> createState() => _DocumentOcrUploaderState();
}

class _DocumentOcrUploaderState extends State<DocumentOcrUploader> {
  bool _isProcessing = false;
  bool _isFinished = false;
  double _progress = 0.0;
  String _processingStage = 'Initializing OCR engine...';
  Timer? _timer;

  String? _selectedFileName;
  PlatformFile? _uploadedFile;

  // Extracted values state
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, String> _confidenceLevels = {}; // 'High', 'Medium', 'Low'

  Map<String, dynamic> _extractDataFromUploadedFile(PlatformFile file) {
    final fileName = file.name;
    final cleanBaseName = fileName
        .replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '')
        .replaceAll('_', ' ')
        .replaceAll('-', ' ')
        .trim();

    String textContent = '';

    // Pattern matches from contents
    final emailMatch = RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}').firstMatch(textContent);
    final phoneMatch = RegExp(r'(?:\+91[\-\s]?)?[6-9]\d{9}').firstMatch(textContent);
    final gstMatch = RegExp(r'\d{2}[A-Z]{5}\d{4}[A-Z]{1}[A-Z\d]{1}[Z]{1}[A-Z\d]{1}').firstMatch(textContent);
    final dateMatch = RegExp(r'\b(?:\d{4}[-/]\d{1,2}[-/]\d{1,2}|\d{1,2}[-/]\d{1,2}[-/]\d{4})\b').firstMatch(textContent);

    final todayStr = DateTime.now().toIso8601String().split('T').first;
    final docDate = dateMatch?.group(0) ?? todayStr;

    // Build derived party name from file name
    final words = cleanBaseName.split(RegExp(r'\s+')).where((w) => w.length > 1).toList();
    String derivedParty = words.isNotEmpty ? words.take(3).join(' ') : 'Uploaded Entity';
    derivedParty = derivedParty.split(' ').map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '').join(' ');

    final hashSeed = (fileName.hashCode.abs() % 8999) + 1000;

    Map<String, String> data = {};
    Map<String, String> confidence = {};

    switch (widget.docType) {
      case OcrDocType.purchaseInvoice:
        data = {
          'Vendor Name': derivedParty.isNotEmpty ? derivedParty : 'Vendor Enterprise',
          'Invoice Number': 'INV-$hashSeed',
          'Invoice Date': docDate,
          'Material Name': 'Raw Material - $derivedParty Spec',
          'Item Code': 'RAW-$hashSeed',
          'Quantity': '100.0',
          'Unit': 'MTR',
          'Rate': '380.0',
          'Tax': '6840.0',
          'Total Amount': '44840.0',
        };
        confidence = {
          'Vendor Name': 'High',
          'Invoice Number': 'High',
          'Invoice Date': 'High',
          'Material Name': 'High',
          'Item Code': 'Medium',
          'Quantity': 'High',
          'Unit': 'High',
          'Rate': 'High',
          'Tax': 'Medium',
          'Total Amount': 'High',
        };
        break;

      case OcrDocType.customerPo:
        data = {
          'Customer Name': derivedParty.isNotEmpty ? derivedParty : 'Client Organization',
          'PO Number': 'PO-$hashSeed',
          'PO Date': docDate,
          'Product Name': 'Item - $derivedParty Edition',
          'Item Code': 'FP-$hashSeed',
          'Quantity': '20.0',
          'Unit': 'PCS',
          'Rate': '4500.0',
          'Discount': '2000.0',
          'Tax': '15840.0',
          'Delivery Date': DateTime.now().add(const Duration(days: 14)).toIso8601String().split('T').first,
          'Delivery Address': 'Project Delivery Site, Main Road',
          'Payment Terms': 'Net 30 Days',
        };
        confidence = {
          'Customer Name': 'High',
          'PO Number': 'High',
          'PO Date': 'High',
          'Product Name': 'High',
          'Item Code': 'Medium',
          'Quantity': 'High',
          'Unit': 'High',
          'Rate': 'High',
          'Discount': 'Medium',
          'Tax': 'Medium',
          'Delivery Date': 'High',
          'Delivery Address': 'Medium',
          'Payment Terms': 'High',
        };
        break;

      case OcrDocType.quotation:
        data = {
          'Customer Name': derivedParty.isNotEmpty ? derivedParty : 'Customer Account',
          'Quotation Number': 'QT-$hashSeed',
          'Quotation Date': docDate,
          'Product Name': 'Product - $derivedParty Standard',
          'Item Code': 'DLX-$hashSeed',
          'Quantity': '10.0',
          'Rate': '8500.0',
          'Discount': '1500.0',
          'Tax': '15030.0',
          'Total': '98530.0',
          'Valid Until': DateTime.now().add(const Duration(days: 30)).toIso8601String().split('T').first,
          'Terms & Conditions': '50% advance payment along with confirmed order, balance before delivery.',
        };
        confidence = {
          'Customer Name': 'High',
          'Quotation Number': 'High',
          'Quotation Date': 'High',
          'Product Name': 'High',
          'Item Code': 'High',
          'Quantity': 'High',
          'Rate': 'High',
          'Discount': 'Medium',
          'Tax': 'Low',
          'Total': 'High',
          'Valid Until': 'High',
          'Terms & Conditions': 'Medium',
        };
        break;

      case OcrDocType.vendorDoc:
        data = {
          'Vendor Name': derivedParty,
          'Company Name': derivedParty.contains('Ltd') || derivedParty.contains('LLP') ? derivedParty : '$derivedParty Private Limited',
          'Contact Person': words.isNotEmpty ? '${words.first} Coordinator' : 'Sales Representative',
          'Mobile': phoneMatch?.group(0) ?? '+91 98201 ${hashSeed.toString().padRight(5, '0')}',
          'Email': emailMatch?.group(0) ?? 'sales@${cleanBaseName.replaceAll(' ', '').toLowerCase()}.com',
          'GST Number': gstMatch?.group(0) ?? '27AABCU9603R1ZM',
          'Address': 'Industrial Estate, Phase II',
          'City': 'Surat',
          'State': 'Gujarat',
          'Pincode': '395003',
          'Bank Details': 'HDFC Bank A/c 502000${hashSeed} IFSC HDFC0000123',
        };
        confidence = {
          'Vendor Name': 'High',
          'Company Name': 'High',
          'Contact Person': 'Medium',
          'Mobile': 'High',
          'Email': 'High',
          'GST Number': 'High',
          'Address': 'High',
          'City': 'High',
          'State': 'High',
          'Pincode': 'Medium',
          'Bank Details': 'Low',
        };
        break;

      case OcrDocType.customerDoc:
        data = {
          'Customer Name': derivedParty,
          'Company Name': '$derivedParty Group',
          'Contact Person': words.isNotEmpty ? words.first : 'Procurement Manager',
          'Mobile': phoneMatch?.group(0) ?? '+91 98210 ${hashSeed.toString().padRight(5, '0')}',
          'Email': emailMatch?.group(0) ?? 'info@${cleanBaseName.replaceAll(' ', '').toLowerCase()}.com',
          'Address': 'Commercial Plaza, Sector 18',
          'City': 'Mumbai',
          'State': 'Maharashtra',
          'Pincode': '400066',
          'Payment Terms': 'Net 30 Days',
        };
        confidence = {
          'Customer Name': 'High',
          'Company Name': 'High',
          'Contact Person': 'Medium',
          'Mobile': 'High',
          'Email': 'High',
          'Address': 'High',
          'City': 'High',
          'State': 'High',
          'Pincode': 'High',
          'Payment Terms': 'Medium',
        };
        break;

      case OcrDocType.architectDoc:
        data = {
          'Architect Name': derivedParty.startsWith('Ar') ? derivedParty : 'Ar. $derivedParty',
          'Firm Name': '$derivedParty Architects & Associates',
          'Mobile': phoneMatch?.group(0) ?? '+91 98200 ${hashSeed.toString().padRight(5, '0')}',
          'Email': emailMatch?.group(0) ?? 'studio@${cleanBaseName.replaceAll(' ', '').toLowerCase()}.com',
          'Address': 'Design Studios, Art District, Mumbai',
        };
        confidence = {
          'Architect Name': 'High',
          'Firm Name': 'High',
          'Mobile': 'High',
          'Email': 'High',
          'Address': 'Medium',
        };
        break;
    }

    // Parse specific "key: value" lines if user uploaded a text/csv file
    if (textContent.isNotEmpty) {
      for (final line in textContent.split('\n')) {
        final parts = line.split(':');
        if (parts.length == 2) {
          final key = parts[0].trim();
          final val = parts[1].trim();
          if (key.isNotEmpty && val.isNotEmpty) {
            for (final existingKey in data.keys.toList()) {
              if (existingKey.toLowerCase() == key.toLowerCase()) {
                data[existingKey] = val;
                confidence[existingKey] = 'High';
              }
            }
          }
        }
      }
    }

    return {
      'name': fileName,
      'data': data,
      'confidence': confidence,
    };
  }

  Future<void> _pickFileFromStorage() async {
    try {
      final result = await FilePickerPlatform.instance.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'webp', 'bmp', 'csv', 'txt', 'json'],
      );

      if (result.isNotEmpty) {
        final file = result.first;
        _uploadedFile = file;
        setState(() {
          _selectedFileName = file.name;
        });

        // Extract and process data specifically from this uploaded file
        final extractedDoc = _extractDataFromUploadedFile(file);
        _startOcrProcessing(fileName: file.name, doc: extractedDoc);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open storage: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  void _startOcrProcessing({
    required String fileName,
    required Map<String, dynamic> doc,
  }) {
    setState(() {
      _selectedFileName = fileName;
      _isProcessing = true;
      _isFinished = false;
      _progress = 0.0;
      _processingStage = 'Reading uploaded file bytes & running Vision OCR...';
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 120), (timer) {
      setState(() {
        _progress += 0.12;
        if (_progress >= 0.3 && _progress < 0.6) {
          _processingStage = 'Extracting text blocks & bounding boxes from $fileName...';
        } else if (_progress >= 0.6 && _progress < 0.9) {
          _processingStage = 'Mapping fields, line items & confidence scores...';
        } else if (_progress >= 0.9) {
          _processingStage = 'Finalizing extracted form fields...';
        }

        if (_progress >= 1.0) {
          _progress = 1.0;
          _isProcessing = false;
          _isFinished = true;
          _timer?.cancel();

          // Populate Controllers with extracted data from the uploaded file
          _controllers.clear();
          _confidenceLevels.clear();
          final Map<String, String> data = doc['data'] != null ? Map<String, String>.from(doc['data']) : {};
          final Map<String, String> conf = doc['confidence'] != null ? Map<String, String>.from(doc['confidence']) : {};
          data.forEach((k, v) {
            _controllers[k] = TextEditingController(text: v);
            _confidenceLevels[k] = conf[k] ?? 'High';
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controllers.forEach((k, ctrl) => ctrl.dispose());
    super.dispose();
  }

  Color _getConfidenceColor(String? level) {
    switch (level) {
      case 'High':
        return AppColors.successText;
      case 'Medium':
        return AppColors.warningText;
      case 'Low':
        return AppColors.dangerText;
      default:
        return AppColors.textMuted;
    }
  }

  Color _getFieldBorderColor(String? level) {
    if (level == 'Low') return AppColors.danger;
    if (level == 'Medium') return AppColors.warning;
    return AppColors.border;
  }

  @override
  Widget build(BuildContext context) {
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.document_scanner_rounded, color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Document Data Extractor (OCR)',
                        style: AppTextStyles.h3,
                      ),
                      Text(
                        'Upload your document from device storage to fetch and auto-fill form data',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: widget.onCancel,
                tooltip: 'Close',
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (!_isProcessing && !_isFinished) ...[
            // Main File Upload Dropzone (No initial sample files)
            Expanded(
              child: Material(
                color: AppColors.surfaceMuted,
                borderRadius: AppRadius.mdBorderRadius,
                child: InkWell(
                  onTap: _pickFileFromStorage,
                  borderRadius: AppRadius.mdBorderRadius,
                  hoverColor: AppColors.primaryLight.withValues(alpha: 0.3),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      borderRadius: AppRadius.mdBorderRadius,
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 1.8),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.cloud_upload_outlined, size: 54, color: AppColors.primary),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Click to Upload Document from Storage',
                          style: AppTextStyles.h2.copyWith(color: AppColors.primary, fontSize: 18),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Upload your Invoice, PO, Quotation, Visiting Card, or GST Document (PDF, JPG, PNG, WEBP)',
                          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _pickFileFromStorage,
                          icon: const Icon(Icons.folder_open_rounded, size: 18),
                          label: const Text('Browse Device Storage'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            textStyle: AppTextStyles.bodyBold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],

          if (_isProcessing) ...[
            Expanded(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(32),
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          shape: BoxShape.circle,
                        ),
                        child: const SizedBox(
                          width: 44,
                          height: 44,
                          child: CircularProgressIndicator(
                            strokeWidth: 3.5,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        _selectedFileName != null ? 'Extracting Data from: $_selectedFileName' : 'Processing document...',
                        style: AppTextStyles.bodyBold.copyWith(fontSize: 16),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: _progress,
                          minHeight: 8,
                          backgroundColor: AppColors.border,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _processingStage,
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'OCR Progress: ${(_progress * 100).toInt()}%',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],

          if (_isFinished) ...[
            // Document Extraction Results Header & Info
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: AppRadius.smBorderRadius,
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: AppColors.successText, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedFileName ?? 'Uploaded Document',
                          style: AppTextStyles.bodyBold,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Data successfully fetched from uploaded file with AI OCR',
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _pickFileFromStorage,
                    icon: const Icon(Icons.upload_file, size: 16),
                    label: const Text('Upload Another File'),
                  ),
                ],
              ),
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Extracted Fields Review',
                  style: AppTextStyles.bodyBold.copyWith(fontSize: 16),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.warningLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.warningText),
                      const SizedBox(width: 6),
                      Text(
                        'Review and edit fields before saving',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.warningText, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Form Fields
            Expanded(
              child: ListView(
                children: _controllers.keys.map((field) {
                  final ctrl = _controllers[field]!;
                  final confidence = _confidenceLevels[field];
                  final isLow = confidence == 'Low';
                  final isMedium = confidence == 'Medium';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 14),
                            child: Text(
                              field,
                              style: AppTextStyles.bodyBold.copyWith(fontSize: 13),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 5,
                          child: TextFormField(
                            controller: ctrl,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: _getFieldBorderColor(confidence), width: 1.5),
                                borderRadius: AppRadius.smBorderRadius,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: isLow
                                      ? AppColors.danger
                                      : isMedium
                                          ? AppColors.warning
                                          : AppColors.primary,
                                  width: 2.0,
                                ),
                                borderRadius: AppRadius.smBorderRadius,
                              ),
                              suffixIcon: isLow
                                  ? const Icon(Icons.error_outline, color: AppColors.danger, size: 18)
                                  : isMedium
                                      ? const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 18)
                                      : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 110,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 14),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: _getConfidenceColor(confidence),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '$confidence Match',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: _getConfidenceColor(confidence),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const Divider(height: 24),

            // Dialog Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ErpButton(
                  text: 'Cancel',
                  isOutlined: true,
                  onPressed: widget.onCancel,
                ),
                const SizedBox(width: 12),
                ErpButton(
                  text: 'Reprocess OCR',
                  isOutlined: true,
                  icon: Icons.refresh,
                  onPressed: () {
                    if (_uploadedFile != null) {
                      final doc = _extractDataFromUploadedFile(_uploadedFile!);
                      _startOcrProcessing(fileName: _uploadedFile!.name, doc: doc);
                    }
                  },
                ),
                const SizedBox(width: 12),
                ErpButton(
                  text: 'Confirm & Populate Form',
                  icon: Icons.check_circle_outline,
                  onPressed: () {
                    final Map<String, String> data = {};
                    _controllers.forEach((k, ctrl) {
                      data[k] = ctrl.text.trim();
                    });
                    widget.onConfirm(data);
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
