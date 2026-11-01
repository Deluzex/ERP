import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/app/routes/app_routes.dart';
import 'package:frontend/core/api/token_storage.dart';
import 'package:frontend/core/models/purchase_model.dart';
import 'package:frontend/core/models/sale_model.dart';
import 'package:frontend/core/storage/form_draft_service.dart';
import 'package:frontend/core/storage/tab_session_storage.dart';
import 'package:frontend/features/masters/screens/bom_screen.dart';
import 'package:frontend/features/purchase/screens/create_purchase_screen.dart';
import 'package:frontend/features/sales/screens/create_sales_order_screen.dart';
import 'package:frontend/features/production/screens/create_production_screen.dart';
import 'package:frontend/shared/providers/app_state_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Refresh Persistence & Form Data Recovery System E2E Suite', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      TabSessionStorage.resetTabId();
      await TokenStorage.instance.init();
      TokenStorage.instance.clear();
      await FormDraftService.instance.clearAllDrafts();
    });

    test('1. Current Screen Persistence: Restores exact module & route on F5 reload', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'erp_session_user',
        '{"id":"USR-ADMIN","name":"Admin User","email":"admin@deluzex.com","primaryRoleId":"admin","isActive":true}',
      );
      // Simulate user on BOM screen before F5 refresh
      await prefs.setString('erp_last_nav_section', ErpNavSection.billOfMaterials.name);
      await prefs.setInt('erp_session_timestamp', DateTime.now().millisecondsSinceEpoch);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final restored = await container.read(authStateProvider.notifier).restoreSession();
      expect(restored, isTrue);

      final currentSection = container.read(currentNavSectionProvider);
      expect(currentSection, ErpNavSection.billOfMaterials);
    });

    test('2. Detail Panel Drilldown: Restores active detail view stack across browser refresh', () async {
      final container1 = ProviderContainer();
      final stackNotifier = container1.read(activeRecordDetailsStackProvider.notifier);

      // User opens Sales Invoice detail view from Sales List
      await stackNotifier.push('INV-2026-0042', 'sales_invoice', ErpNavSection.salesInvoiceList);
      expect(container1.read(activeRecordDetailsStackProvider).length, 1);
      expect(container1.read(activeRecordDetailsStackProvider).first.recordId, 'INV-2026-0042');

      // Check that TabSessionStorage has persisted it
      final storedStack = await TabSessionStorage.getItem('erp_active_details_stack');
      expect(storedStack, isNotNull);
      expect(storedStack, contains('INV-2026-0042'));

      // New container simulates browser reload
      final container2 = ProviderContainer();
      addTearDown(container2.dispose);

      await container2.read(activeRecordDetailsStackProvider.notifier).loadFromStorage();
      final reloadedStack = container2.read(activeRecordDetailsStackProvider);
      expect(reloadedStack.length, 1);
      expect(reloadedStack.first.recordId, 'INV-2026-0042');
      expect(reloadedStack.first.parentSection, ErpNavSection.salesInvoiceList);
    });

    test('3. Edit Purchase Context Protection: Restores editing purchase without duplicate ID', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'erp_session_user',
        '{"id":"USR-ADMIN","name":"Admin User","email":"admin@deluzex.com","primaryRoleId":"admin","isActive":true}',
      );
      await prefs.setString('erp_last_nav_section', ErpNavSection.createPurchase.name);
      await prefs.setInt('erp_session_timestamp', DateTime.now().millisecondsSinceEpoch);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final db = container.read(databaseServiceProvider);
      // Create existing purchase in DB
      final purchase = Purchase(
        id: 'PUR-EXISTING-99',
        purchaseNumber: 'DLZ/PO/2026/0099',
        vendorId: 'VND-001',
        vendorName: 'Acme Hardware',
        vendorInvoiceNumber: 'INV-ACME-888',
        purchaseDate: DateTime.now(),
        invoiceDate: DateTime.now(),
        items: [],
        subtotalAmount: 50000.0,
        gstAmount: 9000.0,
        totalAmount: 59000.0,
        paidAmount: 20000.0,
        pendingAmount: 39000.0,
        paymentMode: PaymentMode.bankTransfer,
        status: PurchaseStatus.saved,
        createdAt: DateTime.now(),
      );
      db.purchases.add(purchase);

      // User was editing this purchase before reload
      await TabSessionStorage.setItem('erp_editing_purchase_id', 'PUR-EXISTING-99');

      final restored = await container.read(authStateProvider.notifier).restoreSession();
      expect(restored, isTrue);

      final editingPurchase = container.read(editingPurchaseProvider);
      expect(editingPurchase, isNotNull);
      expect(editingPurchase!.id, 'PUR-EXISTING-99');
      expect(editingPurchase.vendorInvoiceNumber, 'INV-ACME-888');
    });

    test('4. Purchase Form Draft: Saves and rehydrates vendor, line items, and prices', () async {
      final purchaseDraft = {
        'selectedVendorId': 'VND-002',
        'vendorInvoice': 'SUPP-INV-9988',
        'paidAmount': '15000',
        'notes': 'Urgent procurement for Project Alpha',
        'items': [
          {
            'itemType': 'rawMaterial',
            'itemId': 'RM-001',
            'itemName': 'Sim Alloy Rod',
            'itemCode': 'RM-PRD-76177',
            'unit': 'BOX',
            'quantity': 25.0,
            'rate': 1200.0,
            'discount': 500.0,
            'gstPercent': 18.0,
            'transportationCharge': 50.0,
          },
          {
            'itemType': 'finishedProduct',
            'itemId': 'FP-002',
            'itemName': 'Crystal Pendant Lamp',
            'itemCode': 'FP-SL2-1301',
            'unit': 'PCS',
            'quantity': 10.0,
            'rate': 4500.0,
            'discount': 0.0,
            'gstPercent': 18.0,
            'transportationCharge': 0.0,
          }
        ]
      };

      await FormDraftService.instance.saveFormDraft(
        module: 'purchase',
        formId: 'create_purchase',
        userId: 'USR-ADMIN',
        data: purchaseDraft,
        debounce: false,
      );

      final loaded = await FormDraftService.instance.loadFormDraft(
        module: 'purchase',
        formId: 'create_purchase',
        userId: 'USR-ADMIN',
      );

      expect(loaded, isNotNull);
      expect(loaded!['selectedVendorId'], 'VND-002');
      expect(loaded['vendorInvoice'], 'SUPP-INV-9988');
      final items = loaded['items'] as List;
      expect(items.length, 2);
      expect(items[0]['itemName'], 'Sim Alloy Rod');
      expect(items[0]['quantity'], 25.0);
      expect(items[1]['itemName'], 'Crystal Pendant Lamp');
      expect(items[1]['rate'], 4500.0);
    });

    test('5. Sales Order Form Draft: Saves and recovers customer, items, and taxes', () async {
      final soDraft = {
        'partyType': 'customer',
        'selectedPartyId': 'CUST-009',
        'selectedProjectId': 'PRJ-101',
        'notes': 'Deliver to Site B before Friday',
        'isInterStateTax': true,
        'items': [
          {
            'finishedProductId': 'FP-001',
            'finishedProductName': 'LED Chandelier 40W',
            'finishedProductCode': 'FP-SL2-9884',
            'unit': 'PCS',
            'quantity': 8.0,
            'rate': 16500.0,
            'discount': 1000.0,
            'gstPercent': 18.0,
            'availableStock': 20.0,
          }
        ]
      };

      await FormDraftService.instance.saveFormDraft(
        module: 'sales',
        formId: 'create_sales_order',
        userId: 'USR-ADMIN',
        data: soDraft,
        debounce: false,
      );

      final recovered = await FormDraftService.instance.loadFormDraft(
        module: 'sales',
        formId: 'create_sales_order',
        userId: 'USR-ADMIN',
      );

      expect(recovered, isNotNull);
      expect(recovered!['selectedPartyId'], 'CUST-009');
      expect(recovered['isInterStateTax'], isTrue);
      final items = recovered['items'] as List;
      expect(items.length, 1);
      expect(items.first['finishedProductName'], 'LED Chandelier 40W');
      expect(items.first['rate'], 16500.0);
    });

    test('6. BOM Recipe Persistence: Restores create/edit mode and recipe components', () async {
      final bomDraft = {
        'isCreateMode': true,
        'editingBomId': 'BOM-005',
        'bomNumber': 'BOM-005',
        'bomName': 'Premium Pendant Recipe V2',
        'prodQty': '5',
        'selectedProductId': 'FP-001',
        'draftItems': [
          {
            'rawMaterialId': 'RM-101',
            'rawMaterialName': 'Brass Housing',
            'rawMaterialCode': 'RAW-BRS-01',
            'unit': 'PCS',
            'quantityPerUnit': 2.0,
            'unitCost': 350.0,
          },
          {
            'rawMaterialId': 'RM-102',
            'rawMaterialName': 'LED Driver 40W',
            'rawMaterialCode': 'RAW-DRV-40',
            'unit': 'PCS',
            'quantityPerUnit': 1.0,
            'unitCost': 600.0,
          }
        ]
      };

      await FormDraftService.instance.saveFormDraft(
        module: 'masters',
        formId: 'bom_screen',
        userId: 'USR-ADMIN',
        data: bomDraft,
        debounce: false,
      );

      final restoredBom = await FormDraftService.instance.loadFormDraft(
        module: 'masters',
        formId: 'bom_screen',
        userId: 'USR-ADMIN',
      );

      expect(restoredBom, isNotNull);
      expect(restoredBom!['isCreateMode'], isTrue);
      expect(restoredBom['editingBomId'], 'BOM-005');
      expect(restoredBom['bomName'], 'Premium Pendant Recipe V2');
      final components = restoredBom['draftItems'] as List;
      expect(components.length, 2);
      expect(components[0]['rawMaterialName'], 'Brass Housing');
      expect(components[1]['unitCost'], 600.0);
    });

    test('7. Production Order Draft: Restores planned batch quantity and materials used', () async {
      final prodDraft = {
        'selectedFinishedProductId': 'FP-001',
        'actualQty': '50',
        'labourCost': '7500',
        'otherExpenses': '2500',
        'notes': 'High priority production run',
        'rawMaterialsUsed': [
          {
            'rawMaterialId': 'RM-001',
            'rawMaterialName': 'Alloy Rod',
            'rawMaterialCode': 'RM-PRD-76177',
            'unit': 'BOX',
            'quantityUsed': 100.0,
            'unitCost': 1200.0,
          }
        ]
      };

      await FormDraftService.instance.saveFormDraft(
        module: 'production',
        formId: 'create_production',
        userId: 'USR-ADMIN',
        data: prodDraft,
        debounce: false,
      );

      final restoredProd = await FormDraftService.instance.loadFormDraft(
        module: 'production',
        formId: 'create_production',
        userId: 'USR-ADMIN',
      );

      expect(restoredProd, isNotNull);
      expect(restoredProd!['actualQty'], '50');
      expect(restoredProd['labourCost'], '7500');
      final usage = restoredProd['rawMaterialsUsed'] as List;
      expect(usage.length, 1);
      expect(usage.first['quantityUsed'], 100.0);
    });

    test('8. Master Filter & Search Retention: Preserves filters across refresh', () async {
      // 1. Customer filter retention
      final customerFilters = {
        'search': 'Shreeji Builders',
        'role': 'ARCHITECT',
        'balance': 'WITH_BALANCE',
        'page': 2,
      };
      await TabSessionStorage.setItem('erp_filter_customers', jsonEncode(customerFilters));

      final storedCust = await TabSessionStorage.getItem('erp_filter_customers');
      expect(storedCust, isNotNull);
      final decodedCust = jsonDecode(storedCust!);
      expect(decodedCust['search'], 'Shreeji Builders');
      expect(decodedCust['role'], 'ARCHITECT');
      expect(decodedCust['page'], 2);

      // 2. Product filter retention
      final productFilters = {
        'search': 'Chandelier',
        'category': 'CAT-LIGHTING',
        'stock': 'LOW',
        'page': 1,
      };
      await TabSessionStorage.setItem('erp_filter_products', jsonEncode(productFilters));

      final storedProd = await TabSessionStorage.getItem('erp_filter_products');
      expect(storedProd, isNotNull);
      final decodedProd = jsonDecode(storedProd!);
      expect(decodedProd['stock'], 'LOW');
      expect(decodedProd['category'], 'CAT-LIGHTING');
    });

    test('9. Multi-Tab Isolation: Tab A and Tab B drafts never collide or overwrite', () async {
      // Simulate Browser Tab A
      TabSessionStorage.setMockTabId('tab_browser_A');
      await FormDraftService.instance.saveFormDraft(
        module: 'purchase',
        formId: 'create_purchase',
        userId: 'USR-01',
        data: {'vendor': 'Vendor A', 'invoice': 'INV-AAA-111'},
        debounce: false,
      );

      // Simulate Browser Tab B
      TabSessionStorage.setMockTabId('tab_browser_B');
      await FormDraftService.instance.saveFormDraft(
        module: 'purchase',
        formId: 'create_purchase',
        userId: 'USR-01',
        data: {'vendor': 'Vendor B', 'invoice': 'INV-BBB-222'},
        debounce: false,
      );

      // Read from Tab B
      final tabBDraft = await FormDraftService.instance.loadFormDraft(
        module: 'purchase',
        formId: 'create_purchase',
        userId: 'USR-01',
      );
      expect(tabBDraft!['vendor'], 'Vendor B');
      expect(tabBDraft['invoice'], 'INV-BBB-222');

      // Switch back to Tab A and ensure it was NOT overwritten by Tab B
      TabSessionStorage.setMockTabId('tab_browser_A');
      final tabADraft = await FormDraftService.instance.loadFormDraft(
        module: 'purchase',
        formId: 'create_purchase',
        userId: 'USR-01',
      );
      expect(tabADraft!['vendor'], 'Vendor A');
      expect(tabADraft['invoice'], 'INV-AAA-111');
    });

    test('10. User Isolation: User A and User B drafts are strictly segregated', () async {
      await FormDraftService.instance.saveFormDraft(
        module: 'sales',
        formId: 'create_sales_order',
        userId: 'USER_ALEX',
        data: {'customer': 'Alex Private Client'},
        debounce: false,
      );

      await FormDraftService.instance.saveFormDraft(
        module: 'sales',
        formId: 'create_sales_order',
        userId: 'USER_SARAH',
        data: {'customer': 'Sarah Corporate Deal'},
        debounce: false,
      );

      final alexDraft = await FormDraftService.instance.loadFormDraft(
        module: 'sales',
        formId: 'create_sales_order',
        userId: 'USER_ALEX',
      );
      final sarahDraft = await FormDraftService.instance.loadFormDraft(
        module: 'sales',
        formId: 'create_sales_order',
        userId: 'USER_SARAH',
      );

      expect(alexDraft!['customer'], 'Alex Private Client');
      expect(sarahDraft!['customer'], 'Sarah Corporate Deal');
    });

    test('11. Security & Discard Cleanup: Clear draft removes draft from storage', () async {
      await FormDraftService.instance.saveFormDraft(
        module: 'purchase',
        formId: 'create_purchase',
        userId: 'USR-01',
        data: {'vendor': 'Vendor To Discard'},
        debounce: false,
      );

      expect(
        await FormDraftService.instance.hasFormDraft(module: 'purchase', formId: 'create_purchase', userId: 'USR-01'),
        isTrue,
      );

      // User submits or clicks Discard
      await FormDraftService.instance.clearFormDraft(
        module: 'purchase',
        formId: 'create_purchase',
        userId: 'USR-01',
      );

      expect(
        await FormDraftService.instance.hasFormDraft(module: 'purchase', formId: 'create_purchase', userId: 'USR-01'),
        isFalse,
      );
      expect(
        await FormDraftService.instance.loadFormDraft(module: 'purchase', formId: 'create_purchase', userId: 'USR-01'),
        isNull,
      );
    });
  });
}
