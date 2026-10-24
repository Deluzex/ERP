import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/architect_model.dart';
import '../models/bom_model.dart';
import '../models/category_unit_model.dart';
import '../models/customer_model.dart';
import '../models/dealer_model.dart';
import '../models/expense_model.dart';
import '../models/finished_product_model.dart';
import '../models/payment_model.dart';
import '../models/production_model.dart';
import '../models/project_model.dart';
import '../models/purchase_model.dart';
import '../models/raw_material_model.dart';
import '../models/sale_model.dart';
import '../models/stock_movement_model.dart';
import '../models/vendor_model.dart';
import '../../shared/services/mock_database_service.dart';

/// Offline-First Persistent Cache Manager for Deluzex ERP.
/// Implements the Stale-While-Revalidate pattern:
/// 1. Instantly loads previously saved data from local browser storage on page reload.
/// 2. Allows background live API sync without flashing initial mock data.
/// 3. Updates local cache whenever new API data arrives or records are added.
class ErpCacheManager {
  static const String _kPrefix = 'deluzex_cache_';
  static bool _hasLoadedFromCache = false;
  static bool get hasLoadedFromCache => _hasLoadedFromCache;

  // ---------------------------------------------------------------------------
  // Generic Collection Helpers
  // ---------------------------------------------------------------------------
  static Future<void> _saveJsonList<T>(
    SharedPreferences prefs,
    String key,
    List<T> list,
    Map<String, dynamic> Function(T) toJson,
  ) async {
    try {
      final jsonList = list.map(toJson).toList();
      await prefs.setString('$_kPrefix$key', jsonEncode(jsonList));
    } catch (e) {
      if (kDebugMode) debugPrint('[ErpCacheManager] Error saving $key: $e');
    }
  }

  static List<T>? _readJsonList<T>(
    SharedPreferences prefs,
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    try {
      final raw = prefs.getString('$_kPrefix$key');
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((item) => fromJson(item as Map<String, dynamic>)).toList();
      }
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('[ErpCacheManager] Error reading $key: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Load All Cached Collections into MockDatabaseService
  // ---------------------------------------------------------------------------
  static Future<bool> loadAll(MockDatabaseService db) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Check if any cache exists
      final hasAnyCache = prefs.getKeys().any((k) => k.startsWith(_kPrefix));
      if (!hasAnyCache) return false;

      final cachedCustomers = _readJsonList(prefs, 'customers', Customer.fromJson);
      if (cachedCustomers != null && cachedCustomers.isNotEmpty) {
        db.customers = cachedCustomers;
      }

      final cachedVendors = _readJsonList(prefs, 'vendors', Vendor.fromJson);
      if (cachedVendors != null && cachedVendors.isNotEmpty) {
        db.vendors = cachedVendors;
      }

      final cachedDealers = _readJsonList(prefs, 'dealers', Dealer.fromJson);
      if (cachedDealers != null && cachedDealers.isNotEmpty) {
        db.dealers = cachedDealers;
      }

      final cachedArchitects = _readJsonList(prefs, 'architects', Architect.fromJson);
      if (cachedArchitects != null && cachedArchitects.isNotEmpty) {
        db.architects = cachedArchitects;
      }

      final cachedRawMaterials = _readJsonList(prefs, 'raw_materials', RawMaterial.fromJson);
      if (cachedRawMaterials != null && cachedRawMaterials.isNotEmpty) {
        db.rawMaterials = cachedRawMaterials;
      }

      final cachedFinishedProducts = _readJsonList(prefs, 'finished_products', FinishedProduct.fromJson);
      if (cachedFinishedProducts != null && cachedFinishedProducts.isNotEmpty) {
        db.finishedProducts = cachedFinishedProducts;
      }

      final cachedBoms = _readJsonList(prefs, 'boms', BillOfMaterial.fromJson);
      if (cachedBoms != null && cachedBoms.isNotEmpty) {
        db.boms = cachedBoms;
      }

      final cachedPurchases = _readJsonList(prefs, 'purchases', Purchase.fromJson);
      if (cachedPurchases != null && cachedPurchases.isNotEmpty) {
        db.purchases = cachedPurchases;
      }

      final cachedProduction = _readJsonList(prefs, 'production_orders', ProductionOrder.fromJson);
      if (cachedProduction != null && cachedProduction.isNotEmpty) {
        db.productionOrders = cachedProduction;
      }

      final cachedSales = _readJsonList(prefs, 'sales', Sale.fromJson);
      if (cachedSales != null && cachedSales.isNotEmpty) {
        db.sales = cachedSales;
      }

      final cachedCategories = _readJsonList(prefs, 'categories', ItemCategory.fromJson);
      if (cachedCategories != null && cachedCategories.isNotEmpty) {
        db.categories = cachedCategories;
      }

      final cachedUnits = _readJsonList(prefs, 'units', MeasurementUnit.fromJson);
      if (cachedUnits != null && cachedUnits.isNotEmpty) {
        db.units = cachedUnits;
      }

      final cachedProjects = _readJsonList(prefs, 'projects', Project.fromJson);
      if (cachedProjects != null && cachedProjects.isNotEmpty) {
        db.projects = cachedProjects;
      }

      final cachedPayments = _readJsonList(prefs, 'payments', ErpPayment.fromJson);
      if (cachedPayments != null && cachedPayments.isNotEmpty) {
        db.payments = cachedPayments;
      }

      final cachedExpenses = _readJsonList(prefs, 'expenses', Expense.fromJson);
      if (cachedExpenses != null && cachedExpenses.isNotEmpty) {
        db.expenses = cachedExpenses;
      }

      final cachedStockMovements = _readJsonList(prefs, 'stock_movements', StockMovement.fromJson);
      if (cachedStockMovements != null && cachedStockMovements.isNotEmpty) {
        db.stockMovements = cachedStockMovements;
      }

      _hasLoadedFromCache = true;
      db.notifyListeners();
      if (kDebugMode) {
        debugPrint('[ErpCacheManager] Successfully restored all masters and transactions from local cache.');
      }
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[ErpCacheManager] Error in loadAll: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Save All Current Collections from MockDatabaseService into Local Storage
  // ---------------------------------------------------------------------------
  static Future<void> saveAll(MockDatabaseService db) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await Future.wait([
        _saveJsonList(prefs, 'customers', db.customers, _customerToCache),
        _saveJsonList(prefs, 'vendors', db.vendors, _vendorToCache),
        _saveJsonList(prefs, 'dealers', db.dealers, _dealerToCache),
        _saveJsonList(prefs, 'architects', db.architects, _architectToCache),
        _saveJsonList(prefs, 'raw_materials', db.rawMaterials, _rawMaterialToCache),
        _saveJsonList(prefs, 'finished_products', db.finishedProducts, _finishedProductToCache),
        _saveJsonList(prefs, 'boms', db.boms, (b) => b.toJson()),
        _saveJsonList(prefs, 'purchases', db.purchases, _purchaseToCache),
        _saveJsonList(prefs, 'production_orders', db.productionOrders, (p) => p.toJson()),
        _saveJsonList(prefs, 'sales', db.sales, _saleToCache),
        _saveJsonList(prefs, 'categories', db.categories, _categoryToCache),
        _saveJsonList(prefs, 'units', db.units, _unitToCache),
        _saveJsonList(prefs, 'projects', db.projects, _projectToCache),
        _saveJsonList(prefs, 'payments', db.payments, (p) => p.toJson()),
        _saveJsonList(prefs, 'expenses', db.expenses, (e) => e.toJson()),
        _saveJsonList(prefs, 'stock_movements', db.stockMovements, (s) => s.toJson()),
      ]);

      if (kDebugMode) {
        debugPrint('[ErpCacheManager] Saved latest database snapshot to local cache.');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[ErpCacheManager] Error in saveAll: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Targeted Cache Saves (Single Collection for fast updates)
  // ---------------------------------------------------------------------------
  static Future<void> saveCustomers(List<Customer> list) async {
    final prefs = await SharedPreferences.getInstance();
    await _saveJsonList(prefs, 'customers', list, _customerToCache);
  }

  static Future<void> savePurchases(List<Purchase> list) async {
    final prefs = await SharedPreferences.getInstance();
    await _saveJsonList(prefs, 'purchases', list, _purchaseToCache);
  }

  static Future<void> saveSales(List<Sale> list) async {
    final prefs = await SharedPreferences.getInstance();
    await _saveJsonList(prefs, 'sales', list, _saleToCache);
  }

  static Future<void> saveRawMaterials(List<RawMaterial> list) async {
    final prefs = await SharedPreferences.getInstance();
    await _saveJsonList(prefs, 'raw_materials', list, _rawMaterialToCache);
  }

  static Future<void> saveFinishedProducts(List<FinishedProduct> list) async {
    final prefs = await SharedPreferences.getInstance();
    await _saveJsonList(prefs, 'finished_products', list, _finishedProductToCache);
  }

  static Future<void> saveProductionOrders(List<ProductionOrder> list) async {
    final prefs = await SharedPreferences.getInstance();
    await _saveJsonList(prefs, 'production_orders', list, (p) => p.toJson());
  }

  static Future<void> saveBoms(List<BillOfMaterial> list) async {
    final prefs = await SharedPreferences.getInstance();
    await _saveJsonList(prefs, 'boms', list, (b) => b.toJson());
  }

  // ---------------------------------------------------------------------------
  // Clear Cache on Logout
  // ---------------------------------------------------------------------------
  static Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith(_kPrefix)).toList();
      for (final k in keys) {
        await prefs.remove(k);
      }
      _hasLoadedFromCache = false;
      if (kDebugMode) debugPrint('[ErpCacheManager] Cleared local cache.');
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Cache Serializers (Ensuring 100% field preservation)
  // ---------------------------------------------------------------------------
  static Map<String, dynamic> _customerToCache(Customer c) => {
        'id': c.id,
        'name': c.name,
        'mobile': c.mobile,
        'email': c.email,
        'gstNumber': c.gstNumber,
        'address': c.address,
        'state': c.state,
        'pincode': c.pincode,
        'stateCode': c.stateCode,
        'linkedArchitectId': c.linkedArchitectId,
        'isAlsoArchitect': c.isAlsoArchitect,
        'outstandingAmount': c.outstandingAmount,
        'creditBalance': c.creditBalance,
        'createdAt': c.createdAt.toIso8601String(),
        'isDeleted': c.isDeleted,
        'deletedAt': c.deletedAt?.toIso8601String(),
      };

  static Map<String, dynamic> _vendorToCache(Vendor v) => {
        'id': v.id,
        'name': v.name,
        'contactPerson': v.contactPerson,
        'mobile': v.mobile,
        'email': v.email,
        'gstNumber': v.gstNumber,
        'panNumber': v.panNumber,
        'address': v.address,
        'state': v.state,
        'pincode': v.pincode,
        'paymentTerms': v.paymentTerms,
        'creditLimit': v.creditLimit,
        'outstandingBalance': v.outstandingBalance,
        'defaultTransportationCharges': v.defaultTransportationCharges,
        'isDeleted': v.isDeleted,
        'deleteReason': v.deleteReason,
        'deletedAt': v.deletedAt?.toIso8601String(),
        'createdAt': v.createdAt.toIso8601String(),
      };

  static Map<String, dynamic> _dealerToCache(Dealer d) => {
        'id': d.id,
        'name': d.name,
        'contactPerson': d.contactPerson,
        'mobile': d.mobile,
        'companyName': d.companyName,
        'email': d.email,
        'gstNumber': d.gstNumber,
        'address': d.address,
        'state': d.state,
        'pincode': d.pincode,
        'stateCode': d.stateCode,
        'outstandingAmount': d.outstandingAmount,
        'isDeleted': d.isDeleted,
        'deletedAt': d.deletedAt?.toIso8601String(),
        'createdAt': d.createdAt.toIso8601String(),
      };

  static Map<String, dynamic> _architectToCache(Architect a) => {
        'id': a.id,
        'name': a.name,
        'companyName': a.companyName,
        'mobile': a.mobile,
        'email': a.email,
        'gstNumber': a.gstNumber,
        'address': a.address,
        'state': a.state,
        'pincode': a.pincode,
        'stateCode': a.stateCode,
        'defaultCommissionRate': a.defaultCommissionRate,
        'totalCommissionEarned': a.totalCommissionEarned,
        'pendingCommission': a.pendingCommission,
        'approvedCommission': a.approvedCommission,
        'paidCommission': a.paidCommission,
        'linkedCustomerId': a.linkedCustomerId,
        'isAlsoCustomer': a.isAlsoCustomer,
        'isDeleted': a.isDeleted,
        'deletedAt': a.deletedAt?.toIso8601String(),
        'createdAt': a.createdAt.toIso8601String(),
      };

  static Map<String, dynamic> _rawMaterialToCache(RawMaterial rm) => {
        'id': rm.id,
        'name': rm.name,
        'itemCode': rm.itemCode,
        'categoryId': rm.categoryId,
        'categoryName': rm.categoryName,
        'unitId': rm.unitId,
        'unit': rm.unit,
        'hsnSacCode': rm.hsnSacCode,
        'currentStock': rm.currentStock,
        'openingStock': rm.openingStock,
        'minimumStock': rm.minimumStock,
        'reorderLevel': rm.reorderLevel,
        'defaultPurchasePrice': rm.defaultPurchasePrice,
        'transportationCharge': rm.transportationCharge,
        'gstPercent': rm.gstPercent,
        'preferredVendorIds': rm.preferredVendorIds,
        'preferredVendorNames': rm.preferredVendorNames,
        'isDeleted': rm.isDeleted,
        'deletedAt': rm.deletedAt?.toIso8601String(),
        'createdAt': rm.createdAt.toIso8601String(),
        'updatedAt': rm.updatedAt.toIso8601String(),
      };

  static Map<String, dynamic> _finishedProductToCache(FinishedProduct fp) => {
        'id': fp.id,
        'name': fp.name,
        'itemCode': fp.itemCode,
        'categoryId': fp.categoryId,
        'categoryName': fp.categoryName,
        'unitId': fp.unitId,
        'unit': fp.unit,
        'hsnSacCode': fp.hsnSacCode,
        'currentStock': fp.currentStock,
        'purchasedStock': fp.purchasedStock,
        'producedStock': fp.producedStock,
        'reservedStock': fp.reservedStock,
        'openingStock': fp.openingStock,
        'minimumStock': fp.minimumStock,
        'costPrice': fp.costPrice,
        'transportationCharge': fp.transportationCharge,
        'dealerSellingPrice': fp.dealerSellingPrice,
        'customerSellingPrice': fp.customerSellingPrice,
        'gstPercent': fp.gstPercent,
        'isDeleted': fp.isDeleted,
        'deletedAt': fp.deletedAt?.toIso8601String(),
        'createdAt': fp.createdAt.toIso8601String(),
        'updatedAt': fp.updatedAt.toIso8601String(),
      };

  static Map<String, dynamic> _purchaseToCache(Purchase p) => {
        'id': p.id,
        'purchaseNumber': p.purchaseNumber,
        'purchaseDate': p.purchaseDate.toIso8601String(),
        'vendorId': p.vendorId,
        'vendorName': p.vendorName,
        'vendorCompanyName': p.vendorCompanyName,
        'vendorInvoiceNumber': p.vendorInvoiceNumber,
        'invoiceDate': p.invoiceDate.toIso8601String(),
        'purchaseType': p.purchaseType.name,
        'items': p.items.map((i) => i.toJson()).toList(),
        'subtotalAmount': p.subtotalAmount,
        'discountAmount': p.discountAmount,
        'taxableAmount': p.taxableAmount,
        'cgstAmount': p.cgstAmount,
        'sgstAmount': p.sgstAmount,
        'igstAmount': p.igstAmount,
        'gstAmount': p.gstAmount,
        'transportationCharges': p.transportationCharges,
        'totalAmount': p.totalAmount,
        'paidAmount': p.paidAmount,
        'pendingAmount': p.pendingAmount,
        'paymentMode': p.paymentMode.name,
        'status': p.status.name,
        'notes': p.notes,
        'attachmentUrl': p.attachmentUrl,
        'projectId': p.projectId,
        'projectName': p.projectName,
        'createdAt': p.createdAt.toIso8601String(),
      };

  static Map<String, dynamic> _saleToCache(Sale s) => {
        'id': s.id,
        'invoiceNumber': s.invoiceNumber,
        'documentType': s.documentType.name,
        'partyType': s.partyType.name,
        'partyId': s.partyId,
        'partyName': s.partyName,
        'customerContactPerson': s.customerContactPerson,
        'customerMobile': s.customerMobile,
        'customerEmail': s.customerEmail,
        'customerGstNumber': s.customerGstNumber,
        'billingAddress': s.billingAddress,
        'shippingAddress': s.shippingAddress,
        'projectId': s.projectId,
        'projectName': s.projectName,
        'architectId': s.architectId,
        'architectName': s.architectName,
        'salesExecutive': s.salesExecutive,
        'saleDate': s.saleDate.toIso8601String(),
        'items': s.items.map((i) => i.toJson()).toList(),
        'subtotalAmount': s.subtotalAmount,
        'discountAmount': s.discountAmount,
        'taxableAmount': s.taxableAmount,
        'cgstAmount': s.cgstAmount,
        'sgstAmount': s.sgstAmount,
        'igstAmount': s.igstAmount,
        'gstAmount': s.gstAmount,
        'totalAmount': s.totalAmount,
        'paidAmount': s.paidAmount,
        'pendingAmount': s.pendingAmount,
        'paymentMode': s.paymentMode.name,
        'status': s.status.name,
        'architectCommissionAmount': s.architectCommissionAmount,
        'notes': s.notes,
        'termsAndConditions': s.termsAndConditions,
        'bankDetails': s.bankDetails,
        'createdAt': s.createdAt.toIso8601String(),
        'updatedAt': s.updatedAt?.toIso8601String(),
        'validUntil': s.validUntil?.toIso8601String(),
        'revisionNumber': s.revisionNumber,
        'originalQuotationId': s.originalQuotationId,
        'parentQuotationId': s.parentQuotationId,
        'parentQuotationNumber': s.parentQuotationNumber,
        'quotationStatus': s.quotationStatus?.name,
        'proformaStatus': s.proformaStatus?.name,
        'proformaReferenceId': s.proformaReferenceId,
        'proformaNumber': s.proformaNumber,
        'salesOrderNumber': s.salesOrderNumber,
        'salesOrderReferenceId': s.salesOrderReferenceId,
      };

  static Map<String, dynamic> _categoryToCache(ItemCategory c) => {
        'id': c.id,
        'name': c.name,
        'description': c.description,
      };

  static Map<String, dynamic> _unitToCache(MeasurementUnit u) => {
        'id': u.id,
        'name': u.name,
        'symbol': u.symbol,
      };

  static Map<String, dynamic> _projectToCache(Project p) => {
        'id': p.id,
        'projectCode': p.projectCode,
        'name': p.name,
        'customerId': p.customerId,
        'customerName': p.customerName,
        'dealerId': p.dealerId,
        'dealerName': p.dealerName,
        'architectId': p.architectId,
        'architectName': p.architectName,
        'startDate': p.startDate.toIso8601String(),
        'expectedCompletionDate': p.expectedCompletionDate?.toIso8601String(),
        'actualCompletionDate': p.actualCompletionDate?.toIso8601String(),
        'status': p.status.name,
        'budgetAmount': p.budgetAmount,
        'totalSalesAmount': p.totalSalesAmount,
        'totalCommissionAmount': p.totalCommissionAmount,
        'siteState': p.siteState,
        'siteStateCode': p.siteStateCode,
        'siteAddress': p.siteAddress,
        'sitePincode': p.sitePincode,
        'posVerified': p.posVerified,
        'notes': p.notes,
        'isDeleted': p.isDeleted,
        'deleteReason': p.deleteReason,
        'createdAt': p.createdAt.toIso8601String(),
        'updatedAt': p.updatedAt?.toIso8601String(),
      };
}

