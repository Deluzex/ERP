import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/models/raw_material_model.dart';
import 'package:frontend/shared/services/mock_database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockDatabaseService db;

  setUp(() {
    db = MockDatabaseService();
  });

  group('BOM Raw Material Type Safety & Workflow Tests', () {
    test('Positive: strongly typed List<RawMaterial> deduplication preserves element type', () {
      final List<RawMaterial> rawList = db.rawMaterials;
      final seenRmIds = <String>{};
      final List<RawMaterial> uniqueRms = rawList.where((rm) => rm.id.isNotEmpty && seenRmIds.add(rm.id)).toList();

      expect(uniqueRms, isA<List<RawMaterial>>());
      expect(uniqueRms.isNotEmpty, isTrue);

      // Verify orElse closure matches (() => RawMaterial) signature exactly without runtime TypeError
      final RawMaterial Function() fallback = () => uniqueRms.first;
      expect(fallback, isA<RawMaterial Function()>());

      final RawMaterial match = uniqueRms.firstWhere(
        (r) => r.id == uniqueRms.first.id,
        orElse: () => uniqueRms.first,
      );
      expect(match.id, equals(uniqueRms.first.id));
    });

    test('Negative: unknown raw material id safely returns fallback RawMaterial without throwing', () {
      final List<RawMaterial> rawList = db.rawMaterials;
      final seenRmIds = <String>{};
      final List<RawMaterial> uniqueRms = rawList.where((rm) => rm.id.isNotEmpty && seenRmIds.add(rm.id)).toList();

      const nonExistentId = 'NON-EXISTENT-RM-9999';
      final RawMaterial fallbackResult = uniqueRms.firstWhere(
        (r) => r.id == nonExistentId,
        orElse: () => uniqueRms.first,
      );

      expect(fallbackResult, isA<RawMaterial>());
      expect(fallbackResult.id, equals(uniqueRms.first.id));
    });

    test('Edge case: duplicate IDs in raw material list are filtered to unique and maintain typing', () {
      final duplicateRm = db.rawMaterials.first.copyWith(
        id: 'RM-DUP-01',
        name: 'Duplicate Component',
      );

      final List<RawMaterial> listWithDups = [
        duplicateRm,
        duplicateRm,
        ...db.rawMaterials,
      ];

      final seenRmIds = <String>{};
      final List<RawMaterial> uniqueRms = listWithDups.where((rm) => rm.id.isNotEmpty && seenRmIds.add(rm.id)).toList();

      final dupCount = uniqueRms.where((r) => r.id == 'RM-DUP-01').length;
      expect(dupCount, equals(1));

      final RawMaterial chosen = uniqueRms.firstWhere(
        (r) => r.id == 'RM-DUP-01',
        orElse: () => uniqueRms.first,
      );
      expect(chosen.name, equals('Duplicate Component'));
    });
  });
}

