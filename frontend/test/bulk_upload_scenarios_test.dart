import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/utils/csv_helper.dart';
import 'package:frontend/core/widgets/bulk_upload_dialog.dart';
import 'package:frontend/shared/providers/app_state_providers.dart';
import 'package:frontend/shared/services/mock_database_service.dart';

void main() {
  group('Bulk Upload 4-Scenario Test Data Suite', () {
    late ProviderContainer container;
    late MockDatabaseService db;

    setUp(() {
      db = MockDatabaseService();
      container = ProviderContainer(
        overrides: [
          databaseServiceProvider.overrideWith((ref) => db),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('Positive: raw_materials_bulk_test.csv covers ALL, VALID, ERRORS, and DUPLICATES exactly', () {
      final file = File('../bulk-upload-test-files/raw_materials_bulk_test.csv');
      expect(file.existsSync(), isTrue, reason: 'Test file raw_materials_bulk_test.csv must exist');

      final content = file.readAsStringSync();
      final grid = CsvHelper.parseCsv(content);
      expect(grid.length, 7, reason: '1 header + 6 data rows = 7 rows');

      final header = grid[0];
      expect(header.contains('Material Name*'), isTrue);
      expect(header.contains('Item Code / SKU*'), isTrue);
      expect(header.contains('Category*'), isTrue);
      expect(header.contains('Unit*'), isTrue);

      // Validate each row simulation
      final staged = <StagedRow>[];
      final seenCodes = <String>{};

      for (int i = 1; i < grid.length; i++) {
        final row = grid[i];
        final name = row[0].trim();
        final code = row[1].trim().toUpperCase();
        final cat = row[2].trim();
        final unit = row[3].trim();
        final hsn = row[4].trim();
        final opening = row[5].trim();
        final minStock = row[6].trim();
        final reorder = row[7].trim();
        final price = row[8].trim();
        final transport = row[9].trim();
        final gst = row[10].trim();
        final vendor = row[11].trim();

        final stagedRow = StagedRow(
          rowNumber: i + 1,
          fields: {
            'name': name,
            'itemCode': code,
            'category': cat,
            'unit': unit,
            'hsnSacCode': hsn,
            'openingStock': opening,
            'minimumStock': minStock,
            'reorderLevel': reorder,
            'defaultPurchasePrice': price,
            'transportationCharge': transport,
            'gstPercent': gst,
            'preferredVendor': vendor,
          },
        );

        // Validation logic
        if (name.isEmpty) stagedRow.fieldErrors['name'] = 'Name is required';
        if (code.isEmpty) {
          stagedRow.fieldErrors['itemCode'] = 'Item code is required';
        } else if (seenCodes.contains(code)) {
          stagedRow.fieldErrors['itemCode'] = 'Duplicate Item Code in this file';
        } else {
          seenCodes.add(code);
          final inDb = db.rawMaterials.any((r) => !r.isDeleted && r.itemCode.toUpperCase() == code);
          if (inDb) {
            stagedRow.status = StagedRowStatus.duplicate;
            staged.add(stagedRow);
            continue;
          }
        }

        final catMatch = db.categories.any((c) => c.name.toLowerCase().trim() == cat.toLowerCase().trim());
        if (!catMatch) stagedRow.fieldErrors['category'] = 'Category "$cat" not found in master';

        final unitMatch = db.units.any((u) => u.symbol.toLowerCase().trim() == unit.toLowerCase().trim() || u.name.toLowerCase().trim() == unit.toLowerCase().trim());
        if (!unitMatch) stagedRow.fieldErrors['unit'] = 'Unit "$unit" not found in master';

        final opNum = double.tryParse(opening);
        if (opNum == null || opNum < 0) stagedRow.fieldErrors['openingStock'] = 'Invalid opening stock';

        final gstNum = double.tryParse(gst);
        if (gstNum == null || gstNum < 0 || gstNum > 100) stagedRow.fieldErrors['gstPercent'] = 'Invalid GST';

        if (stagedRow.fieldErrors.isNotEmpty) {
          stagedRow.status = StagedRowStatus.invalid;
        } else {
          stagedRow.status = StagedRowStatus.valid;
        }

        staged.add(stagedRow);
      }

      // Assert counts for all 4 scenarios
      final allCount = staged.length;
      final validCount = staged.where((r) => r.status == StagedRowStatus.valid).length;
      final errorCount = staged.where((r) => r.status == StagedRowStatus.invalid).length;
      final duplicateCount = staged.where((r) => r.status == StagedRowStatus.duplicate).length;

      expect(allCount, 6, reason: 'Total rows must be 6');
      expect(validCount, 2, reason: 'Valid rows must be 2');
      expect(errorCount, 3, reason: 'Invalid rows must be 3 (missing name/category, invalid unit/gst, duplicate in file)');
      expect(duplicateCount, 1, reason: 'Duplicate in DB (RAW-AL-6063) must be 1');
    });

    test('Positive: finished_products_bulk_test.csv covers ALL, VALID, ERRORS, and DUPLICATES exactly', () {
      final file = File('../bulk-upload-test-files/finished_products_bulk_test.csv');
      expect(file.existsSync(), isTrue, reason: 'Test file finished_products_bulk_test.csv must exist');

      final content = file.readAsStringSync();
      final grid = CsvHelper.parseCsv(content);
      expect(grid.length, 7);

      final staged = <StagedRow>[];
      final seenCodes = <String>{};

      for (int i = 1; i < grid.length; i++) {
        final row = grid[i];
        final name = row[0].trim();
        final code = row[1].trim().toUpperCase();
        final cat = row[2].trim();
        final unit = row[3].trim();
        final opening = row[5].trim();
        final cost = row[7].trim();
        final gst = row[11].trim();

        final stagedRow = StagedRow(
          rowNumber: i + 1,
          fields: {
            'name': name,
            'itemCode': code,
            'category': cat,
            'unit': unit,
            'costPrice': cost,
            'gstPercent': gst,
          },
        );

        if (name.isEmpty) stagedRow.fieldErrors['name'] = 'Name is required';
        if (code.isEmpty) {
          stagedRow.fieldErrors['itemCode'] = 'Item code is required';
        } else if (seenCodes.contains(code)) {
          stagedRow.fieldErrors['itemCode'] = 'Duplicate Item Code in this file';
        } else {
          seenCodes.add(code);
          final inDb = db.finishedProducts.any((p) => !p.isDeleted && p.itemCode.toUpperCase() == code);
          if (inDb) {
            stagedRow.status = StagedRowStatus.duplicate;
            staged.add(stagedRow);
            continue;
          }
        }

        final catMatch = db.categories.any((c) => c.name.toLowerCase().trim() == cat.toLowerCase().trim());
        if (!catMatch) stagedRow.fieldErrors['category'] = 'Category not found';

        final unitMatch = db.units.any((u) => u.symbol.toLowerCase().trim() == unit.toLowerCase().trim() || u.name.toLowerCase().trim() == unit.toLowerCase().trim());
        if (!unitMatch) stagedRow.fieldErrors['unit'] = 'Unit not found';

        final costNum = double.tryParse(cost);
        if (costNum == null || costNum < 0) stagedRow.fieldErrors['costPrice'] = 'Invalid cost';

        final gstNum = double.tryParse(gst);
        if (gstNum == null || gstNum < 0 || gstNum > 100) stagedRow.fieldErrors['gstPercent'] = 'Invalid GST';

        if (stagedRow.fieldErrors.isNotEmpty) {
          stagedRow.status = StagedRowStatus.invalid;
        } else {
          stagedRow.status = StagedRowStatus.valid;
        }

        staged.add(stagedRow);
      }

      final allCount = staged.length;
      final validCount = staged.where((r) => r.status == StagedRowStatus.valid).length;
      final errorCount = staged.where((r) => r.status == StagedRowStatus.invalid).length;
      final duplicateCount = staged.where((r) => r.status == StagedRowStatus.duplicate).length;

      expect(allCount, 6);
      expect(validCount, 2);
      expect(errorCount, 3);
      expect(duplicateCount, 1);
    });

    test('Positive: recordBulkUploadHistory stores user audit records accurately in database', () {
      final initialCount = db.bulkUploadHistory.length;

      db.recordBulkUploadHistory(
        fileName: 'raw_materials_bulk_test.csv',
        masterType: 'Raw Materials',
        uploadedBy: 'Alex Sterling',
        totalRows: 500,
        importedRows: 50,
        errorRows: 100,
        duplicateRows: 350,
        status: 'PARTIAL',
        notes: '50 valid items added. 350 duplicates skipped and 100 schema errors flagged.',
      );

      expect(db.bulkUploadHistory.length, initialCount + 1);
      final latest = db.bulkUploadHistory.first;
      expect(latest.fileName, 'raw_materials_bulk_test.csv');
      expect(latest.uploadedBy, 'Alex Sterling');
      expect(latest.totalRows, 500);
      expect(latest.importedRows, 50);
      expect(latest.errorRows, 100);
      expect(latest.duplicateRows, 350);
      expect(latest.status, 'PARTIAL');
      expect(latest.notes, contains('350 duplicates skipped'));
    });

    test('Positive: In-place error resolution workflow - staged rows keep error rows after import', () {
      final staged = <StagedRow>[
        StagedRow(rowNumber: 2, fields: {'name': 'Valid RM 1', 'itemCode': 'RM-01'}, status: StagedRowStatus.valid),
        StagedRow(rowNumber: 3, fields: {'name': 'Valid RM 2', 'itemCode': 'RM-02'}, status: StagedRowStatus.valid),
        StagedRow(rowNumber: 4, fields: {'name': '', 'itemCode': 'RM-03'}, status: StagedRowStatus.invalid),
        StagedRow(rowNumber: 5, fields: {'name': 'Duplicate RM', 'itemCode': 'RAW-AL-6063'}, status: StagedRowStatus.duplicate),
      ];

      final rowsToImport = staged.where((r) => r.isReadyToImport).toList();
      expect(rowsToImport.length, 2);

      // Simulate import completion: valid rows are removed from staging
      staged.removeWhere((r) => rowsToImport.contains(r));

      // Remaining rows are only errors and duplicates
      expect(staged.length, 2);
      expect(staged.any((r) => r.status == StagedRowStatus.invalid), isTrue);
      expect(staged.any((r) => r.status == StagedRowStatus.duplicate), isTrue);

      // Now user resolves error in Row 4
      final errorRow = staged.firstWhere((r) => r.status == StagedRowStatus.invalid);
      errorRow.fields['name'] = 'Fixed Raw Material';
      errorRow.fieldErrors.clear();
      errorRow.status = StagedRowStatus.valid;

      // Now it's ready to import without re-uploading!
      final newlyReady = staged.where((r) => r.isReadyToImport).toList();
      expect(newlyReady.length, 1);
      expect(newlyReady.first.fields['name'], 'Fixed Raw Material');
    });
  });
}
