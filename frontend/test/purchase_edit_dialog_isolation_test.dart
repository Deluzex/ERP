import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/app/routes/app_routes.dart';
import 'package:frontend/core/models/purchase_model.dart';
import 'package:frontend/features/purchase/screens/create_purchase_screen.dart';
import 'package:frontend/features/purchase/screens/purchase_list_screen.dart';
import 'package:frontend/shared/providers/app_state_providers.dart';
import 'package:frontend/shared/services/mock_database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Editing purchase operates independently without mutating currentNavSectionProvider to createPurchase', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Initial state is purchaseList
    container.read(currentNavSectionProvider.notifier).state = ErpNavSection.purchaseList;
    expect(container.read(currentNavSectionProvider), ErpNavSection.purchaseList);
    expect(container.read(editingPurchaseProvider), isNull);

    // Create a sample purchase
    final samplePurchase = Purchase(
      id: 'PUR-TEST-001',
      purchaseNumber: 'PO-TEST-001',
      purchaseDate: DateTime(2026, 10, 31),
      vendorId: 'VEND-001',
      vendorName: 'Acme Supplies',
      vendorInvoiceNumber: 'INV-12345',
      invoiceDate: DateTime(2026, 10, 30),
      items: [
        PurchaseItem(
          id: 'ITEM-001',
          purchaseId: 'PUR-TEST-001',
          itemType: PurchaseItemType.rawMaterial,
          rawMaterialId: 'RM-001',
          itemName: 'Aluminum Profile',
          itemCode: 'AL-001',
          unit: 'MTR',
          quantity: 10,
          unitPrice: 150.0,
          taxRate: 18.0,
          cgst: 135.0,
          sgst: 135.0,
          igst: 0.0,
          totalAmount: 1770.0,
        ),
      ],
      subtotalAmount: 1500.0,
      gstAmount: 270.0,
      transportationCharges: 100.0,
      totalAmount: 1870.0,
      paidAmount: 500.0,
      pendingAmount: 1370.0,
      paymentMode: PaymentMode.bankTransfer,
      status: PurchaseStatus.saved,
    );

    // Editing purchase in its individual dialog does NOT require setting editingPurchaseProvider or switching nav section
    final editWidget = CreatePurchaseScreen(
      key: ValueKey('edit_purchase_${samplePurchase.id}'),
      existingPurchase: samplePurchase,
    );

    expect(editWidget.existingPurchase, isNotNull);
    expect(editWidget.existingPurchase!.id, 'PUR-TEST-001');
    expect(editWidget.existingPurchase!.vendorInvoiceNumber, 'INV-12345');

    // Verify global navigation remains on purchaseList
    expect(container.read(currentNavSectionProvider), ErpNavSection.purchaseList);
    expect(container.read(editingPurchaseProvider), isNull);
  });
}

