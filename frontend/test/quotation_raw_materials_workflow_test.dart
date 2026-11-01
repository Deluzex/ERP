import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/models/purchase_model.dart';
import 'package:frontend/core/models/sale_model.dart';
import 'package:frontend/features/sales/screens/create_quotation_screen.dart';
import 'package:frontend/shared/providers/app_state_providers.dart';
import 'package:frontend/shared/services/mock_database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockDatabaseService db;

  setUp(() {
    db = MockDatabaseService();
  });

  group('Quotation Raw Materials & Finished Goods Workflow Tests', () {
    test('Positive: SaleLineItem supports both Finished Goods and Raw Materials serialization', () {
      final fgItem = SaleLineItem(
        itemType: PurchaseItemType.finishedProduct,
        finishedProductId: 'FP-001',
        finishedProductName: 'Architectural Recessed Spotlight',
        finishedProductCode: 'FP-SL1-01',
        quantity: 10.0,
        unit: 'PCS',
        rate: 4000.0,
        discountAmount: 0.0,
        gstPercent: 18.0,
        lineTotal: 47200.0,
      );

      final rmItem = SaleLineItem(
        itemType: PurchaseItemType.rawMaterial,
        rawMaterialId: 'RM-001',
        rawMaterialName: 'Aluminum Housing Extrusion 6063',
        rawMaterialCode: 'RM-ALU-01',
        quantity: 25.0,
        unit: 'KG',
        rate: 350.0,
        discountAmount: 250.0,
        gstPercent: 18.0,
        lineTotal: 10030.0,
      );

      expect(fgItem.itemType, equals(PurchaseItemType.finishedProduct));
      expect(fgItem.displayName, equals('Architectural Recessed Spotlight'));
      expect(fgItem.displayCode, equals('FP-SL1-01'));
      expect(fgItem.itemId, equals('FP-001'));

      expect(rmItem.itemType, equals(PurchaseItemType.rawMaterial));
      expect(rmItem.displayName, equals('Aluminum Housing Extrusion 6063'));
      expect(rmItem.displayCode, equals('RM-ALU-01'));
      expect(rmItem.itemId, equals('RM-001'));

      final fgJson = fgItem.toJson();
      expect(fgJson['itemType'], equals('finished_product'));
      expect(fgJson['finishedProductId'], equals('FP-001'));

      final rmJson = rmItem.toJson();
      expect(rmJson['itemType'], equals('raw_material'));
      expect(rmJson['rawMaterialId'], equals('RM-001'));
      expect(rmJson['rawMaterialName'], equals('Aluminum Housing Extrusion 6063'));

      // Deserialization check
      final parsedRm = SaleLineItem.fromJson(rmJson);
      expect(parsedRm.itemType, equals(PurchaseItemType.rawMaterial));
      expect(parsedRm.rawMaterialId, equals('RM-001'));
      expect(parsedRm.displayName, equals('Aluminum Housing Extrusion 6063'));
    });

    testWidgets('Positive: CreateQuotationScreen renders Add Finished Good & Add Raw Material buttons and manages items',
        (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseServiceProvider.overrideWith((ref) => db),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: CreateQuotationScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Card Header and buttons exist
      expect(find.text('Quotation Line Items'), findsOneWidget);
      expect(find.text('Add Finished Good'), findsOneWidget);
      // Add Raw Material button is commented out per UI directive
      expect(find.text('Add Raw Material'), findsNothing);

      // Verify first item is rendered with Finished Good
      expect(find.text('Fin Good'), findsWidgets);

      // Tap 'Add Finished Good' button
      final addFgButton = find.text('Add Finished Good');
      await tester.ensureVisible(addFgButton);
      await tester.tap(addFgButton);
      await tester.pumpAndSettle();

      // Should now have 2 items
      expect(find.text('2 Items'), findsOneWidget);
    });
  });
}
