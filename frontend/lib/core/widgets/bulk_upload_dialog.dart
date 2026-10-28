import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../shared/providers/app_state_providers.dart';
import '../utils/csv_helper.dart';
import '../utils/file_downloader/file_downloader.dart';
import 'erp_button.dart';
import 'erp_status_badge.dart';

enum BulkUploadMasterType {
  rawMaterial,
  finishedProduct,
}

enum StagedRowStatus {
  valid,
  invalid,
  duplicate,
}

class StagedRow {
  final int rowNumber;
  final Map<String, String> fields;
  bool isSkipped;
  Map<String, String> fieldErrors;
  StagedRowStatus status;

  StagedRow({
    required this.rowNumber,
    required this.fields,
    this.isSkipped = false,
    Map<String, String>? fieldErrors,
    this.status = StagedRowStatus.valid,
  }) : fieldErrors = fieldErrors ?? {};

  bool get isReadyToImport => status == StagedRowStatus.valid && !isSkipped;
}

class BulkUploadDialog extends ConsumerStatefulWidget {
  final BulkUploadMasterType masterType;

  const BulkUploadDialog({
    super.key,
    required this.masterType,
  });

  static Future<void> show(BuildContext context, BulkUploadMasterType type) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => BulkUploadDialog(masterType: type),
    );
  }

  @override
  ConsumerState<BulkUploadDialog> createState() => _BulkUploadDialogState();
}

class _BulkUploadDialogState extends ConsumerState<BulkUploadDialog> {
  String? _selectedFileName;
  List<StagedRow> _stagedRows = [];
  bool _isParsing = false;
  bool _isImporting = false;
  String? _parseError;
  String? _bannerMessage;
  String _activeFilter = 'ALL'; // ALL, VALID, ERRORS, DUPLICATES
  int _currentPage = 0;
  final int _pageSize = 15;

  bool get isRawMaterial => widget.masterType == BulkUploadMasterType.rawMaterial;
  String get masterTitle => isRawMaterial ? 'Raw Materials' : 'Products';

  // Supported Columns Definition
  List<String> get headers => isRawMaterial
      ? [
          'Material Name*',
          'Item Code / SKU*',
          'Category*',
          'Unit*',
          'HSN / SAC Code',
          'Opening Stock',
          'Minimum Stock',
          'Reorder Level',
          'Purchase Price (INR)',
          'Transport Charge (INR)',
          'GST %',
          'Preferred Vendor',
        ]
      : [
          'Product Name*',
          'Item Code / SKU*',
          'Category*',
          'Unit*',
          'HSN / SAC Code',
          'Opening Stock',
          'Minimum Stock',
          'Cost Price (INR)',
          'Transport Charge (INR)',
          'Dealer Selling Price (INR)',
          'Customer Selling Price (INR)',
          'GST %',
        ];

  // -------------------------------------------------------------
  // Template Generation & Export Existing Data
  // -------------------------------------------------------------
  Future<void> _downloadTemplate() async {
    final db = ref.read(databaseServiceProvider);
    final sampleCat = db.categories.isNotEmpty ? db.categories.first.name : 'Components';
    final sampleUnit = db.units.isNotEmpty ? db.units.first.symbol : 'PCS';
    final sampleVendor = db.vendors.isNotEmpty ? db.vendors.first.name : 'Apex Extrusions Ltd';

    final List<List<dynamic>> csvRows = [headers];

    if (isRawMaterial) {
      final activeMaterials = db.rawMaterials.where((m) => !m.isDeleted).toList();
      if (activeMaterials.isNotEmpty) {
        for (final m in activeMaterials) {
          final vendorName = m.preferredVendorNames.isNotEmpty
              ? m.preferredVendorNames.first
              : (m.preferredVendorIds.isNotEmpty
                  ? (db.vendors.where((v) => v.id == m.preferredVendorIds.first).firstOrNull?.name ?? '')
                  : '');
          csvRows.add([
            m.name,
            m.itemCode,
            m.categoryName,
            m.unit,
            m.hsnSacCode ?? '',
            m.openingStock.toStringAsFixed(2),
            m.minimumStock.toStringAsFixed(2),
            m.reorderLevel.toStringAsFixed(2),
            m.defaultPurchasePrice.toStringAsFixed(2),
            m.transportationCharge.toStringAsFixed(2),
            m.gstPercent.toStringAsFixed(2),
            vendorName,
          ]);
        }
      } else {
        // Fallback sample rows if database has no active raw materials yet
        csvRows.add([
          'Aluminum Alloy Ingot 6063',
          'RM-ALU-01',
          sampleCat,
          sampleUnit,
          '76012010',
          '150.00',
          '25.00',
          '35.00',
          '245.50',
          '12.00',
          '18.00',
          sampleVendor,
        ]);
        csvRows.add([
          'Brass Hex Rod 12mm',
          'RM-BRS-02',
          sampleCat,
          sampleUnit,
          '74072110',
          '80.00',
          '15.00',
          '25.00',
          '410.00',
          '15.00',
          '18.00',
          '',
        ]);
      }
    } else {
      final activeProducts = db.finishedProducts.where((p) => !p.isDeleted).toList();
      if (activeProducts.isNotEmpty) {
        for (final p in activeProducts) {
          csvRows.add([
            p.name,
            p.itemCode,
            p.categoryName,
            p.unit,
            p.hsnSacCode ?? '',
            p.openingStock.toStringAsFixed(2),
            p.minimumStock.toStringAsFixed(2),
            p.costPrice.toStringAsFixed(2),
            p.transportationCharge.toStringAsFixed(2),
            p.dealerSellingPrice.toStringAsFixed(2),
            p.customerSellingPrice.toStringAsFixed(2),
            p.gstPercent.toStringAsFixed(2),
          ]);
        }
      } else {
        // Fallback sample rows if database has no active products yet
        csvRows.add([
          'Architectural Recessed Spotlight 15W',
          'FP-SLZ-101',
          sampleCat,
          sampleUnit,
          '94054090',
          '50.00',
          '10.00',
          '850.00',
          '25.00',
          '1200.00',
          '1650.00',
          '18.00',
        ]);
        csvRows.add([
          'Linear Pendant Profile Light 2M',
          'FP-LIN-202',
          sampleCat,
          sampleUnit,
          '94054090',
          '30.00',
          '5.00',
          '620.00',
          '30.00',
          '950.00',
          '1350.00',
          '18.00',
        ]);
      }
    }

    final csvString = CsvHelper.toCsv(csvRows, sanitizeForSpreadsheet: true);
    final fileName = isRawMaterial ? 'raw_materials_master.csv' : 'product_master.csv';

    await FileDownloader.downloadCsv(csvString, fileName);

    if (mounted) {
      final count = csvRows.length - 1;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Downloaded CSV with $count items: $fileName'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  // -------------------------------------------------------------
  // File Picking & Parsing
  // -------------------------------------------------------------
  Future<void> _pickAndParseFile() async {
    try {
      final result = await FilePickerPlatform.instance.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result.isEmpty) return;

      final PlatformFile file = result.first;
      final fileLength = await file.length();

      // File size validation (2 MB max)
      if (fileLength > 2 * 1024 * 1024) {
        setState(() {
          _parseError = 'File size exceeds 2 MB limit (${(fileLength / (1024 * 1024)).toStringAsFixed(2)} MB).';
        });
        return;
      }

      setState(() {
        _isParsing = true;
        _parseError = null;
        _selectedFileName = file.name;
        _currentPage = 0;
      });

      final bytes = await file.readAsBytes();
      final content = utf8.decode(bytes, allowMalformed: true);

      if (content.trim().isEmpty) {
        setState(() {
          _isParsing = false;
          _parseError = 'Uploaded file is empty.';
        });
        return;
      }

      final parsedGrid = CsvHelper.parseCsv(content);
      if (parsedGrid.isEmpty || parsedGrid.length < 2) {
        setState(() {
          _isParsing = false;
          _parseError = 'CSV file must contain a header row and at least one data row.';
        });
        return;
      }

      // Max 1000 data rows enforcement
      if (parsedGrid.length - 1 > 1000) {
        setState(() {
          _isParsing = false;
          _parseError = 'File contains ${parsedGrid.length - 1} data rows. Maximum permitted limit is 1,000 rows.';
        });
        return;
      }

      final headerRow = parsedGrid[0];
      final columnMap = _buildHeaderIndexMap(headerRow);

      if (!columnMap.containsKey('name') ||
          !columnMap.containsKey('itemCode') ||
          !columnMap.containsKey('category') ||
          !columnMap.containsKey('unit')) {
        setState(() {
          _isParsing = false;
          _parseError =
              'Missing required column headers. Expected at least: "Material Name / Product Name", "Item Code / SKU", "Category", and "Unit".';
        });
        return;
      }

      final List<StagedRow> staged = [];
      final Set<String> seenCodesInBatch = {};

      for (int i = 1; i < parsedGrid.length; i++) {
        final row = parsedGrid[i];
        if (row.every((c) => c.trim().isEmpty)) continue; // skip pure blank rows

        final Map<String, String> fields = {
          'name': _getVal(row, columnMap['name']),
          'itemCode': _getVal(row, columnMap['itemCode']).toUpperCase(),
          'category': _getVal(row, columnMap['category']),
          'unit': _getVal(row, columnMap['unit']),
          'hsnSacCode': _getVal(row, columnMap['hsnSacCode']),
          'openingStock': _getVal(row, columnMap['openingStock'], '0'),
          'minimumStock': _getVal(row, columnMap['minimumStock'], '0'),
          'transportationCharge': _getVal(row, columnMap['transportationCharge'], '0'),
          'gstPercent': _getVal(row, columnMap['gstPercent'], '18'),
        };

        if (isRawMaterial) {
          fields['reorderLevel'] = _getVal(row, columnMap['reorderLevel'], '0');
          fields['defaultPurchasePrice'] = _getVal(row, columnMap['defaultPurchasePrice'], '0');
          fields['preferredVendor'] = _getVal(row, columnMap['preferredVendor']);
        } else {
          fields['costPrice'] = _getVal(row, columnMap['costPrice'], '0');
          fields['dealerSellingPrice'] = _getVal(row, columnMap['dealerSellingPrice'], '0');
          fields['customerSellingPrice'] = _getVal(row, columnMap['customerSellingPrice'], '0');
        }

        final stagedRow = StagedRow(
          rowNumber: i + 1,
          fields: fields,
        );

        _validateRow(stagedRow, seenCodesInBatch);
        staged.add(stagedRow);
      }

      setState(() {
        _isParsing = false;
        _stagedRows = staged;
      });
    } catch (e) {
      setState(() {
        _isParsing = false;
        _parseError = 'Failed to parse file: $e';
      });
    }
  }

  String _getVal(List<String> row, int? index, [String fallback = '']) {
    if (index == null || index < 0 || index >= row.length) return fallback;
    final v = row[index].trim();
    return v.isEmpty ? fallback : v;
  }

  Map<String, int> _buildHeaderIndexMap(List<String> headers) {
    final Map<String, int> map = {};
    for (int i = 0; i < headers.length; i++) {
      final h = headers[i].toLowerCase().replaceAll('*', '').replaceAll('/', ' ').replaceAll('_', ' ').replaceAll('-', ' ').trim();

      if (h.contains('material name') || h.contains('product name') || h == 'name' || h == 'item name') {
        map['name'] = i;
      } else if (h.contains('item code') || h.contains('sku') || h == 'code') {
        map['itemCode'] = i;
      } else if (h.contains('category')) {
        map['category'] = i;
      } else if (h.contains('unit') || h == 'uom') {
        map['unit'] = i;
      } else if (h.contains('hsn') || h.contains('sac')) {
        map['hsnSacCode'] = i;
      } else if (h.contains('opening stock') || h == 'opening' || h == 'stock') {
        map['openingStock'] = i;
      } else if (h.contains('min') && h.contains('stock')) {
        map['minimumStock'] = i;
      } else if (h.contains('reorder')) {
        map['reorderLevel'] = i;
      } else if (h.contains('purchase price') || h.contains('buy price')) {
        map['defaultPurchasePrice'] = i;
      } else if (h.contains('cost price') || h == 'cost') {
        map['costPrice'] = i;
      } else if (h.contains('transport')) {
        map['transportationCharge'] = i;
      } else if (h.contains('dealer')) {
        map['dealerSellingPrice'] = i;
      } else if (h.contains('customer') || h.contains('retail') || h.contains('selling price')) {
        map['customerSellingPrice'] = i;
      } else if (h.contains('gst') || h.contains('tax')) {
        map['gstPercent'] = i;
      } else if (h.contains('vendor') || h.contains('supplier')) {
        map['preferredVendor'] = i;
      }
    }
    return map;
  }

  // -------------------------------------------------------------
  // Row-Level Validation
  // -------------------------------------------------------------
  void _validateRow(StagedRow row, Set<String> seenCodesInBatch) {
    row.fieldErrors.clear();
    final db = ref.read(databaseServiceProvider);

    final name = row.fields['name'] ?? '';
    final code = row.fields['itemCode'] ?? '';
    final catName = row.fields['category'] ?? '';
    final unitSym = row.fields['unit'] ?? '';

    if (name.isEmpty) {
      row.fieldErrors['name'] = 'Name is required';
    }

    if (code.isEmpty) {
      row.fieldErrors['itemCode'] = 'Item code is required';
    } else {
      // 1. In-file duplicate check
      if (seenCodesInBatch.contains(code)) {
        row.fieldErrors['itemCode'] = 'Duplicate Item Code in this file';
      } else {
        seenCodesInBatch.add(code);

        // 2. Database duplicate pre-check
        final alreadyInDb = isRawMaterial
            ? db.rawMaterials.any((r) => !r.isDeleted && r.itemCode.toUpperCase() == code)
            : db.finishedProducts.any((p) => !p.isDeleted && p.itemCode.toUpperCase() == code);

        if (alreadyInDb) {
          row.status = StagedRowStatus.duplicate;
          return;
        }
      }
    }

    // Category Lookup
    if (catName.isEmpty) {
      row.fieldErrors['category'] = 'Category is required';
    } else {
      final matchedCat = db.categories.any(
        (c) => c.name.toLowerCase().trim() == catName.toLowerCase().trim(),
      );
      if (!matchedCat) {
        row.fieldErrors['category'] = 'Category "$catName" not found in master';
      }
    }

    // Unit Lookup
    if (unitSym.isEmpty) {
      row.fieldErrors['unit'] = 'Unit is required';
    } else {
      final matchedUnit = db.units.any(
        (u) =>
            u.symbol.toLowerCase().trim() == unitSym.toLowerCase().trim() ||
            u.name.toLowerCase().trim() == unitSym.toLowerCase().trim(),
      );
      if (!matchedUnit) {
        row.fieldErrors['unit'] = 'Unit "$unitSym" not found in master';
      }
    }

    // Numbers validation
    _validatePositiveNumber(row, 'openingStock', 'Opening Stock');
    _validatePositiveNumber(row, 'minimumStock', 'Minimum Stock');
    _validatePositiveNumber(row, 'transportationCharge', 'Transport Charge');
    _validatePositiveNumber(row, 'gstPercent', 'GST %', maxValue: 100);

    if (isRawMaterial) {
      _validatePositiveNumber(row, 'reorderLevel', 'Reorder Level');
      _validatePositiveNumber(row, 'defaultPurchasePrice', 'Purchase Price');
    } else {
      _validatePositiveNumber(row, 'costPrice', 'Cost Price');
      _validatePositiveNumber(row, 'dealerSellingPrice', 'Dealer Price');
      _validatePositiveNumber(row, 'customerSellingPrice', 'Customer Price');
    }

    if (row.fieldErrors.isNotEmpty) {
      row.status = StagedRowStatus.invalid;
    } else {
      row.status = StagedRowStatus.valid;
    }
  }

  void _validatePositiveNumber(StagedRow row, String fieldKey, String label, {double? maxValue}) {
    final rawVal = row.fields[fieldKey];
    if (rawVal == null || rawVal.trim().isEmpty) return;
    final num? val = double.tryParse(rawVal.trim());
    if (val == null) {
      row.fieldErrors[fieldKey] = '$label must be a valid number';
    } else if (val < 0) {
      row.fieldErrors[fieldKey] = '$label cannot be negative';
    } else if (maxValue != null && val > maxValue) {
      row.fieldErrors[fieldKey] = '$label cannot exceed $maxValue';
    }
  }

  void _revalidateAll() {
    final Set<String> seen = {};
    for (final r in _stagedRows) {
      _validateRow(r, seen);
    }
    setState(() {});
  }

  // -------------------------------------------------------------
  // Inline Quick Edit Dialog
  // -------------------------------------------------------------
  void _openEditRowDialog(StagedRow row) {
    final controllers = <String, TextEditingController>{};
    row.fields.forEach((k, v) {
      controllers[k] = TextEditingController(text: v);
    });

    showDialog(
      context: context,
      builder: (editCtx) {
        return AlertDialog(
          title: Text('Edit Row ${row.rowNumber}', style: AppTextStyles.h2),
          content: Container(
            constraints: const BoxConstraints(maxWidth: 550, maxHeight: 500),
            width: double.infinity,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: controllers.entries.map((entry) {
                  final isErr = row.fieldErrors.containsKey(entry.key);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextFormField(
                      controller: entry.value,
                      decoration: InputDecoration(
                        labelText: entry.key,
                        errorText: isErr ? row.fieldErrors[entry.key] : null,
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          actions: [
            ErpButton(
              text: 'Cancel',
              isOutlined: true,
              onPressed: () => Navigator.of(editCtx).pop(),
            ),
            ErpButton(
              text: 'Save & Revalidate',
              onPressed: () {
                controllers.forEach((k, ctrl) {
                  row.fields[k] = ctrl.text.trim();
                });
                Navigator.of(editCtx).pop();
                _revalidateAll();
              },
            ),
          ],
        );
      },
    );
  }

  // -------------------------------------------------------------
  // Submission & Import Action
  // -------------------------------------------------------------
  Future<void> _submitImport() async {
    final db = ref.read(databaseServiceProvider);
    final rowsToImport = _stagedRows.where((r) => r.isReadyToImport).toList();

    if (rowsToImport.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No valid rows available to import. Please review and resolve row errors.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    // Build Payload for Backend
    final List<Map<String, dynamic>> itemsPayload = [];
    for (final r in rowsToImport) {
      final f = r.fields;

      // Resolve Category ID
      final cat = db.categories.firstWhere(
        (c) => c.name.toLowerCase().trim() == f['category']!.toLowerCase().trim(),
        orElse: () => db.categories.first,
      );

      // Resolve Unit ID
      final unit = db.units.firstWhere(
        (u) =>
            u.symbol.toLowerCase().trim() == f['unit']!.toLowerCase().trim() ||
            u.name.toLowerCase().trim() == f['unit']!.toLowerCase().trim(),
        orElse: () => db.units.first,
      );

      final Map<String, dynamic> itemMap = {
        'name': f['name']!.trim(),
        'itemCode': f['itemCode']!.trim().toUpperCase(),
        'categoryId': cat.id,
        'unitId': unit.id,
        'hsnSacCode': f['hsnSacCode']?.trim().isNotEmpty == true ? f['hsnSacCode']!.trim() : null,
        'openingStock': double.tryParse(f['openingStock'] ?? '0') ?? 0.0,
        'minimumStock': double.tryParse(f['minimumStock'] ?? '0') ?? 0.0,
        'transportationCharge': double.tryParse(f['transportationCharge'] ?? '0') ?? 0.0,
        'gstPercent': double.tryParse(f['gstPercent'] ?? '18') ?? 18.0,
      };

      if (isRawMaterial) {
        itemMap['reorderLevel'] = double.tryParse(f['reorderLevel'] ?? '0') ?? 0.0;
        itemMap['defaultPurchasePrice'] = double.tryParse(f['defaultPurchasePrice'] ?? '0') ?? 0.0;
        final vName = f['preferredVendor']?.trim() ?? '';
        if (vName.isNotEmpty) {
          final vendor = db.vendors.where((v) => v.name.toLowerCase() == vName.toLowerCase()).firstOrNull;
          if (vendor != null) {
            itemMap['preferredVendorIds'] = [vendor.id];
          }
        }
      } else {
        itemMap['costPrice'] = double.tryParse(f['costPrice'] ?? '0') ?? 0.0;
        itemMap['dealerSellingPrice'] = double.tryParse(f['dealerSellingPrice'] ?? '0') ?? 0.0;
        itemMap['customerSellingPrice'] = double.tryParse(f['customerSellingPrice'] ?? '0') ?? 0.0;
      }

      itemsPayload.add(itemMap);
    }

    final totalSubmittedBefore = _stagedRows.length;
    setState(() => _isImporting = true);

    int totalImported = 0;
    int totalDuplicates = 0;
    int totalSkipped = 0;
    int totalFailed = 0;
    final List<Map<String, dynamic>> serverErrors = [];

    // Client-side batch chunking (250 items per batch) to respect payload limits and avoid timeouts
    final int batchSize = 250;
    for (int i = 0; i < itemsPayload.length; i += batchSize) {
      final chunk = itemsPayload.sublist(i, (i + batchSize > itemsPayload.length) ? itemsPayload.length : i + batchSize);
      try {
        final Map<String, dynamic> res = isRawMaterial
            ? await db.bulkImportRawMaterialsAsync(chunk, duplicatePolicy: 'SKIP')
            : await db.bulkImportFinishedProductsAsync(chunk, duplicatePolicy: 'SKIP');

        totalImported += (res['importedCount'] as num?)?.toInt() ?? 0;
        totalDuplicates += (res['duplicateCount'] as num?)?.toInt() ?? 0;
        totalSkipped += (res['skippedCount'] as num?)?.toInt() ?? 0;
        totalFailed += (res['failedCount'] as num?)?.toInt() ?? 0;

        final rawErrors = res['errors'] as List?;
        if (rawErrors != null) {
          for (final err in rawErrors) {
            if (err is Map<String, dynamic>) serverErrors.add(err);
          }
        }
      } catch (e) {
        totalFailed += chunk.length;
        serverErrors.add({
          'message': 'Batch request failed: ${e.toString().replaceFirst("Exception: ", "")}',
        });
      }
    }

    // Remove imported rows from staging so remaining errors/duplicates can be resolved
    if (totalImported > 0) {
      _stagedRows.removeWhere((r) => rowsToImport.contains(r));
    }

    final remainingErrors = _stagedRows.where((r) => r.status == StagedRowStatus.invalid).length;
    final remainingDuplicates = _stagedRows.where((r) => r.status == StagedRowStatus.duplicate).length;

    // Record Bulk Upload Audit History Record
    db.recordBulkUploadHistory(
      fileName: _selectedFileName ?? 'Uploaded Batch',
      masterType: masterTitle,
      uploadedBy: db.currentUser.name,
      totalRows: totalSubmittedBefore,
      importedRows: totalImported,
      errorRows: remainingErrors,
      duplicateRows: totalDuplicates > 0 ? totalDuplicates : remainingDuplicates,
      status: totalImported == 0 ? 'FAILED' : (remainingErrors > 0 ? 'PARTIAL' : 'SUCCESS'),
      notes: '$totalImported items imported into $masterTitle.${remainingErrors > 0 ? " $remainingErrors error rows pending resolution." : " All valid items processed."}',
    );

    setState(() => _isImporting = false);

    if (!mounted) return;

    // Show Import Summary Dialog
    _showSummaryDialog(
      totalSubmitted: itemsPayload.length,
      imported: totalImported,
      duplicates: totalDuplicates,
      skipped: totalSkipped,
      failed: totalFailed,
      errors: serverErrors,
    );
  }

  void _showSummaryDialog({
    required int totalSubmitted,
    required int imported,
    required int duplicates,
    required int skipped,
    required int failed,
    required List<Map<String, dynamic>> errors,
  }) {
    final remainingErrors = _stagedRows.where((r) => r.status == StagedRowStatus.invalid).length;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (summaryCtx) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                imported > 0 ? Icons.check_circle : Icons.warning_amber_rounded,
                color: imported > 0 ? AppColors.success : AppColors.danger,
              ),
              const SizedBox(width: 10),
              Text('Import Results Summary', style: AppTextStyles.h2),
            ],
          ),
          content: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bulk import of $masterTitle completed.',
                  style: AppTextStyles.bodyMedium,
                ),
                const SizedBox(height: 16),
                _summaryRow('Total Rows Processed:', '$totalSubmitted'),
                _summaryRow('Successfully Imported:', '$imported', color: AppColors.success),
                _summaryRow('Duplicates Skipped (Preserved):', '$duplicates', color: AppColors.warning),
                if (failed > 0) _summaryRow('Failed Rows:', '$failed', color: AppColors.danger),
                const SizedBox(height: 16),
                if (errors.isNotEmpty) ...[
                  Text('Server Feedback Details:', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 120),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: errors.length,
                      itemBuilder: (ctx, idx) {
                        final err = errors[idx];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '• ${err['itemCode'] != null ? "[${err['itemCode']}] " : ""}${err['message'] ?? ""}',
                            style: AppTextStyles.caption.copyWith(color: AppColors.danger),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            if (errors.isNotEmpty)
              ErpButton(
                text: 'Download Error Report',
                isOutlined: true,
                icon: Icons.download_outlined,
                onPressed: () {
                  final List<List<dynamic>> errCsv = [
                    ['Row', 'Item Code', 'Field', 'Error Message'],
                  ];
                  for (final e in errors) {
                    errCsv.add([
                      e['rowNumber'] ?? '',
                      e['itemCode'] ?? '',
                      e['field'] ?? '',
                      e['message'] ?? '',
                    ]);
                  }
                  FileDownloader.downloadCsv(
                    CsvHelper.toCsv(errCsv, sanitizeForSpreadsheet: true),
                    'bulk_import_errors.csv',
                  );
                },
              ),
            if (remainingErrors > 0) ...[
              ErpButton(
                text: 'Done & Close',
                isOutlined: true,
                onPressed: () {
                  Navigator.of(summaryCtx).pop(); // pop summary
                  Navigator.of(context).pop(); // pop bulk dialog
                },
              ),
              ErpButton(
                text: 'Resolve Remaining Errors ($remainingErrors)',
                icon: Icons.edit_note,
                onPressed: () {
                  Navigator.of(summaryCtx).pop(); // pop summary ONLY, keep bulk dialog open!
                  setState(() {
                    _activeFilter = 'ERRORS';
                    _currentPage = 0;
                    _bannerMessage =
                        '$imported items successfully imported! $remainingErrors items with errors remain below. Click Edit on any row to fix and import.';
                  });
                },
              ),
            ] else
              ErpButton(
                text: 'Done & Close',
                onPressed: () {
                  Navigator.of(summaryCtx).pop(); // pop summary
                  Navigator.of(context).pop(); // pop bulk dialog
                },
              ),
          ],
        );
      },
    );
  }

  Widget _summaryRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.bodyMedium),
          Text(
            value,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: color ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // Filtered Rows Calculation
  // -------------------------------------------------------------
  List<StagedRow> get _filteredRows {
    switch (_activeFilter) {
      case 'VALID':
        return _stagedRows.where((r) => r.status == StagedRowStatus.valid && !r.isSkipped).toList();
      case 'ERRORS':
        return _stagedRows.where((r) => r.status == StagedRowStatus.invalid).toList();
      case 'DUPLICATES':
        return _stagedRows.where((r) => r.status == StagedRowStatus.duplicate).toList();
      case 'SKIPPED':
        return _stagedRows.where((r) => r.isSkipped).toList();
      default:
        return _stagedRows;
    }
  }

  @override
  Widget build(BuildContext context) {
    final validCount = _stagedRows.where((r) => r.status == StagedRowStatus.valid && !r.isSkipped).length;
    final errorCount = _stagedRows.where((r) => r.status == StagedRowStatus.invalid).length;
    final duplicateCount = _stagedRows.where((r) => r.status == StagedRowStatus.duplicate).length;
    final skippedCount = _stagedRows.where((r) => r.isSkipped).length;

    final filtered = _filteredRows;
    final totalPages = (filtered.length / _pageSize).ceil();
    final paginatedRows = filtered.skip(_currentPage * _pageSize).take(_pageSize).toList();

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      actionsPadding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.upload_file, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Bulk Upload $masterTitle', style: AppTextStyles.h2),
                  const SizedBox(height: 2),
                  Text('Upload multi-record CSV file with automatic schema & reference validation',
                      style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
                ],
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: _isImporting ? null : () => Navigator.of(context).pop(),
          ),
        ],
      ),
      content: Container(
        constraints: BoxConstraints(
          maxWidth: 980,
          maxHeight: MediaQuery.of(context).size.height * 0.78,
        ),
        width: MediaQuery.of(context).size.width * 0.9,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // STEP 1 & 2: Toolbar (Download Template & Pick File)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                children: [
                  ErpButton(
                    text: 'Download Template',
                    icon: Icons.download_outlined,
                    isOutlined: true,
                    onPressed: _downloadTemplate,
                  ),
                  const SizedBox(width: 14),
                  ErpButton(
                    text: _selectedFileName == null ? 'Upload File' : 'Change File',
                    icon: Icons.upload_file,
                    onPressed: _pickAndParseFile,
                  ),
                  const SizedBox(width: 16),
                  if (_selectedFileName != null)
                    Expanded(
                      child: Text(
                        'File: $_selectedFileName (${_stagedRows.length} data rows)',
                        style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (_isParsing) ...[
                    const SizedBox(width: 12),
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ],
                ],
              ),
            ),

            if (_parseError != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.danger),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_parseError!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.danger)),
                    ),
                  ],
                ),
              ),
            ],

            if (_bannerMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.success),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: AppColors.success, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _bannerMessage!,
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.success, fontWeight: FontWeight.w600),
                      ),
                    ),
                    InkWell(
                      onTap: () => setState(() => _bannerMessage = null),
                      child: const Icon(Icons.close, size: 18, color: AppColors.success),
                    ),
                  ],
                ),
              ),
            ],

            if (_stagedRows.isNotEmpty) ...[
              const SizedBox(height: 14),

              // KPI Filter Badges Bar
              Row(
                children: [
                  _filterTab('ALL', 'All (${_stagedRows.length})', AppColors.primary),
                  const SizedBox(width: 8),
                  _filterTab('VALID', 'Valid ($validCount)', AppColors.success),
                  const SizedBox(width: 8),
                  _filterTab('ERRORS', 'Errors ($errorCount)', AppColors.danger),
                  const SizedBox(width: 8),
                  _filterTab('DUPLICATES', 'Duplicates ($duplicateCount)', AppColors.warning),
                  if (skippedCount > 0) ...[
                    const SizedBox(width: 8),
                    _filterTab('SKIPPED', 'Skipped ($skippedCount)', Colors.grey),
                  ],
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Duplicate Policy: SKIP',
                      style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700, color: const Color(0xFF475569)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // STAGING PREVIEW TABLE
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: filtered.isEmpty
                      ? Center(
                          child: Text(
                            'No rows match filter "$_activeFilter".',
                            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
                          ),
                        )
                      : ListView.separated(
                          itemCount: paginatedRows.length,
                          separatorBuilder: (ctx, i) => const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                          itemBuilder: (ctx, idx) {
                            final row = paginatedRows[idx];
                            return _buildRowItem(row);
                          },
                        ),
                ),
              ),

              // PAGINATION CONTROLS
              if (totalPages > 1) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Showing ${_currentPage * _pageSize + 1} to ${((_currentPage + 1) * _pageSize).clamp(1, filtered.length)} of ${filtered.length} rows',
                      style: AppTextStyles.caption,
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
                        ),
                        Text('${_currentPage + 1} / $totalPages', style: AppTextStyles.caption),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ],

            if (_stagedRows.isEmpty && _parseError == null) ...[
              const Spacer(),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_upload_outlined, size: 54, color: AppColors.primary.withValues(alpha: 0.5)),
                    const SizedBox(height: 14),
                    Text('Download the CSV template, populate your records, and upload it here.',
                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted)),
                    const SizedBox(height: 6),
                    Text('Supported: CSV only (RFC 4180) • Max 1,000 rows • Max 2 MB',
                        style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
                  ],
                ),
              ),
              const Spacer(),
            ],
          ],
        ),
      ),
      actions: [
        ErpButton(
          text: 'Cancel',
          isOutlined: true,
          onPressed: _isImporting ? null : () => Navigator.of(context).pop(),
        ),
        if (_stagedRows.isNotEmpty)
          ErpButton(
            text: _isImporting ? 'Importing Batch...' : 'Confirm & Import ($validCount Items)',
            icon: Icons.check,
            isLoading: _isImporting,
            onPressed: (_isImporting || validCount == 0) ? null : _submitImport,
          ),
      ],
    );
  }

  Widget _filterTab(String key, String label, Color color) {
    final isSelected = _activeFilter == key;
    return InkWell(
      onTap: () => setState(() {
        _activeFilter = key;
        _currentPage = 0;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : color,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildRowItem(StagedRow row) {
    Color rowBg = Colors.white;
    if (row.isSkipped) {
      rowBg = const Color(0xFFF8FAFC);
    } else if (row.status == StagedRowStatus.invalid) {
      rowBg = AppColors.danger.withValues(alpha: 0.04);
    } else if (row.status == StagedRowStatus.duplicate) {
      rowBg = AppColors.warning.withValues(alpha: 0.05);
    }

    final hasErrors = row.fieldErrors.isNotEmpty;

    return Container(
      color: rowBg,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          // Row Number Badge
          Container(
            width: 44,
            padding: const EdgeInsets.symmetric(vertical: 2),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '#${row.rowNumber}',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
            ),
          ),
          const SizedBox(width: 10),

          // Status Badge
          if (row.isSkipped)
            const ErpStatusBadge(label: 'SKIPPED', backgroundColor: Color(0xFFE2E8F0), textColor: Color(0xFF475569))
          else if (row.status == StagedRowStatus.valid)
            ErpStatusBadge.success('VALID')
          else if (row.status == StagedRowStatus.duplicate)
            const ErpStatusBadge(label: 'DUPLICATE (SKIP)', backgroundColor: Color(0xFFFEF3C7), textColor: Color(0xFF92400E))
          else
            ErpStatusBadge.danger('INVALID'),

          const SizedBox(width: 12),

          // Code & Name
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      row.fields['itemCode'] ?? '',
                      style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        row.fields['name'] ?? '',
                        style: AppTextStyles.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (hasErrors) ...[
                  const SizedBox(height: 2),
                  Text(
                    row.fieldErrors.values.join(' • '),
                    style: AppTextStyles.caption.copyWith(color: AppColors.danger, fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
          ),

          // Category & Unit
          Expanded(
            flex: 2,
            child: Text(
              '${row.fields['category']} • ${row.fields['unit']}',
              style: AppTextStyles.caption,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Opening Stock
          SizedBox(
            width: 80,
            child: Text(
              'Qty: ${row.fields['openingStock']}',
              style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.left,
            ),
          ),

          const SizedBox(width: 12),

          // Row Actions (Skip & Edit)
          IconButton(
            icon: Icon(
              row.isSkipped ? Icons.replay : Icons.block,
              size: 18,
              color: row.isSkipped ? AppColors.primary : Colors.grey,
            ),
            tooltip: row.isSkipped ? 'Unskip Row' : 'Skip Row',
            onPressed: () {
              setState(() {
                row.isSkipped = !row.isSkipped;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
            tooltip: 'Edit Row Data',
            onPressed: () => _openEditRowDialog(row),
          ),
        ],
      ),
    );
  }
}
