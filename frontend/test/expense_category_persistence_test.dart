import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api/expense_categories_api_service.dart';
import 'package:frontend/core/models/category_unit_model.dart';
import 'package:frontend/core/storage/erp_cache_manager.dart';
import 'package:frontend/shared/services/mock_database_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Expense Category Persistence & API Binding Test Suite', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    tearDown(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    });

    test('Positive: ExpenseCategoryMasterItem.fromJson correctly parses camelCase and snake_case backend payloads', () {
      final backendJson = {
        'id': 'exp-cat-uuid-001',
        'name': 'Site Rigging & Cranes',
        'code': 'EXP-RIGGING',
        'description': 'Heavy crane rentals for high-bay lighting installations',
        'isActive': true,
        'linkedKey': 'transportation',
      };

      final item = ExpenseCategoryMasterItem.fromJson(backendJson);
      expect(item.id, 'exp-cat-uuid-001');
      expect(item.name, 'Site Rigging & Cranes');
      expect(item.code, 'EXP-RIGGING');
      expect(item.description, 'Heavy crane rentals for high-bay lighting installations');
      expect(item.isActive, isTrue);
      expect(item.linkedKey, 'transportation');

      // snake_case edge case
      final snakeJson = {
        'id': 'exp-cat-uuid-002',
        'name': 'Warehouse Consumables',
        'code': 'EXP-CONSUM',
        'description': 'Packaging and wrapping tape',
        'is_active': false,
        'linked_key': 'other',
      };
      final itemSnake = ExpenseCategoryMasterItem.fromJson(snakeJson);
      expect(itemSnake.id, 'exp-cat-uuid-002');
      expect(itemSnake.isActive, isFalse);
      expect(itemSnake.linkedKey, 'other');
    });

    test('Positive: ExpenseCategoryMasterItem.toJson preserves id and fields for cache & persistence', () {
      final item = ExpenseCategoryMasterItem(
        id: 'EXP-CUSTOM-1',
        name: 'Site Scaffold Hire',
        code: 'EXP-SCAFFOLD',
        description: 'Monthly scaffold rental fees',
        isActive: true,
        linkedKey: 'projectExpense',
      );

      final json = item.toJson();
      expect(json['id'], 'EXP-CUSTOM-1');
      expect(json['name'], 'Site Scaffold Hire');
      expect(json['code'], 'EXP-SCAFFOLD');
      expect(json['description'], 'Monthly scaffold rental fees');
      expect(json['isActive'], isTrue);
      expect(json['linkedKey'], 'projectExpense');

      final roundTrip = ExpenseCategoryMasterItem.fromJson(json);
      expect(roundTrip.id, item.id);
      expect(roundTrip.name, item.name);
      expect(roundTrip.code, item.code);
      expect(roundTrip.description, item.description);
      expect(roundTrip.isActive, item.isActive);
      expect(roundTrip.linkedKey, item.linkedKey);
    });

    test('Positive: ErpCacheManager saves and restores expense categories across reloads', () async {
      final db = MockDatabaseService();
      final customCategory = ExpenseCategoryMasterItem(
        id: 'EXP-CAT-RELOAD-TEST',
        name: 'Architectural Mockups',
        code: 'EXP-MOCKUP',
        description: 'Physical acrylic scale models for architects',
        isActive: true,
      );

      db.expenseCategoryMasterList.insert(0, customCategory);

      // Save to cache
      await ErpCacheManager.saveExpenseCategories(db.expenseCategoryMasterList);

      // Simulate browser refresh with a fresh MockDatabaseService
      final freshDb = MockDatabaseService();
      expect(freshDb.expenseCategoryMasterList.any((c) => c.id == 'EXP-CAT-RELOAD-TEST'), isFalse);

      // Restore from cache
      final restored = await ErpCacheManager.loadAll(freshDb);
      expect(restored, isTrue);
      expect(freshDb.expenseCategoryMasterList.any((c) => c.id == 'EXP-CAT-RELOAD-TEST'), isTrue);

      final restoredItem = freshDb.expenseCategoryMasterList.firstWhere((c) => c.id == 'EXP-CAT-RELOAD-TEST');
      expect(restoredItem.name, 'Architectural Mockups');
      expect(restoredItem.code, 'EXP-MOCKUP');
    });

    test('Positive: ExpenseCategoriesApiService instantiates with singleton ApiClient', () {
      final api = ExpenseCategoriesApiService();
      expect(api, isNotNull);
    });

    test('Positive: MockDatabaseService addExpenseCategoryAsync saves record and updates state', () async {
      final db = MockDatabaseService();
      final initialCount = db.expenseCategoryMasterList.length;

      final added = await db.addExpenseCategoryAsync(
        name: 'Workshop Tool Maintenance',
        code: 'EXP-TOOLING',
        description: 'Drill bit and CNC cutter sharpening',
      );

      expect(added.name, 'Workshop Tool Maintenance');
      expect(added.code, 'EXP-TOOLING');
      expect(db.expenseCategoryMasterList.length, initialCount + 1);
      expect(db.expenseCategoryMasterList.first.name, 'Workshop Tool Maintenance');
    });
  });
}
