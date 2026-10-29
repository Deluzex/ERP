import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/routes/app_routes.dart';
import '../../shared/providers/app_state_providers.dart';

/// Non-web (Desktop/Mobile/Unit Tests) implementation of NavigationHistory.
/// Maintains an in-memory history stack to support back navigation.
class NavigationHistory {
  NavigationHistory._();

  static final List<ErpNavSection> _history = [];
  static WidgetRef? _ref;
  static GlobalKey<NavigatorState>? _navigatorKey;
  static bool _isNavigatingBack = false;

  static bool get canGoBack => _history.length > 1;

  static void initialize(WidgetRef ref, {GlobalKey<NavigatorState>? navigatorKey}) {
    _ref = ref;
    _navigatorKey = navigatorKey;
    _history.clear();
    final initial = ref.read(currentNavSectionProvider);
    _history.add(initial);
  }

  static void onSectionChanged(ErpNavSection section) {
    if (_isNavigatingBack) return;
    if (_history.isNotEmpty && _history.last == section) return;
    _history.add(section);
  }

  static void onDetailStateChanged(bool isDetailOpen, ErpNavSection currentSection) {
    // Non-web stub handles details via detail stack provider
  }

  static bool goBack() {
    if (_history.length <= 1 || _ref == null) return false;
    _isNavigatingBack = true;
    try {
      _history.removeLast(); // Remove current
      final previous = _history.last;
      _ref!.read(currentNavSectionProvider.notifier).state = previous;
      return true;
    } finally {
      _isNavigatingBack = false;
    }
  }

  static void dispose() {
    _history.clear();
    _ref = null;
    _navigatorKey = null;
    _isNavigatingBack = false;
  }

  static String pathToSection(ErpNavSection section) {
    switch (section) {
      case ErpNavSection.dashboard:
        return 'dashboard';
      case ErpNavSection.inventoryDashboard:
        return 'inventory-dashboard';
      case ErpNavSection.rawMaterialStock:
        return 'raw-material-stock';
      case ErpNavSection.finishedProductStock:
        return 'finished-product-stock';
      case ErpNavSection.stockMovement:
        return 'stock-movement';
      case ErpNavSection.stockAdjustments:
        return 'stock-adjustments';
      case ErpNavSection.purchaseDashboard:
        return 'purchase-dashboard';
      case ErpNavSection.purchaseList:
        return 'purchase-invoices';
      case ErpNavSection.createPurchase:
        return 'create-purchase';
      case ErpNavSection.purchaseHistory:
        return 'purchase-history';
      case ErpNavSection.vendorPayments:
        return 'vendor-payments';
      case ErpNavSection.productionDashboard:
        return 'production-dashboard';
      case ErpNavSection.productionOrders:
        return 'production-invoices';
      case ErpNavSection.createProduction:
        return 'create-production';
      case ErpNavSection.productionHistory:
        return 'production-history';
      case ErpNavSection.productionCosting:
        return 'production-costing';
      case ErpNavSection.salesDashboard:
        return 'sales-dashboard';
      case ErpNavSection.quotations:
        return 'quotations';
      case ErpNavSection.createQuotation:
        return 'create-quotation';
      case ErpNavSection.proformaInvoices:
        return 'proforma-invoices';
      case ErpNavSection.salesOrders:
        return 'sales-orders';
      case ErpNavSection.createSalesOrder:
        return 'create-sales-order';
      case ErpNavSection.salesDeliveries:
        return 'sales-deliveries';
      case ErpNavSection.salesInvoiceList:
        return 'sales-invoices';
      case ErpNavSection.createSale:
        return 'create-sale';
      case ErpNavSection.salesReturns:
        return 'sales-returns';
      case ErpNavSection.createSalesReturn:
        return 'create-sales-return';
      case ErpNavSection.projectList:
        return 'project-list';
      case ErpNavSection.createProject:
        return 'create-project';
      case ErpNavSection.paymentsDashboard:
        return 'payments-dashboard';
      case ErpNavSection.customerPayments:
        return 'customer-payments';
      case ErpNavSection.dealerPayments:
        return 'dealer-payments';
      case ErpNavSection.vendorPaymentsSection:
        return 'vendor-payments-section';
      case ErpNavSection.commissionPayments:
        return 'commission-payments';
      case ErpNavSection.expenseList:
        return 'expense-list';
      case ErpNavSection.mastersDashboard:
        return 'masters-dashboard';
      case ErpNavSection.categoriesUnits:
        return 'categories-units';
      case ErpNavSection.vendors:
        return 'vendors';
      case ErpNavSection.customers:
        return 'customers';
      case ErpNavSection.dealers:
        return 'dealers';
      case ErpNavSection.architects:
        return 'architects';
      case ErpNavSection.rawMaterials:
        return 'raw-materials';
      case ErpNavSection.finishedProducts:
        return 'finished-products';
      case ErpNavSection.billOfMaterials:
        return 'bill-of-materials';
      case ErpNavSection.reportsDashboard:
        return 'reports-dashboard';
      case ErpNavSection.inventoryReports:
        return 'inventory-reports';
      case ErpNavSection.purchaseReports:
        return 'purchase-reports';
      case ErpNavSection.productionReports:
        return 'production-reports';
      case ErpNavSection.salesReports:
        return 'sales-reports';
      case ErpNavSection.projectReports:
        return 'project-reports';
      case ErpNavSection.commissionReports:
        return 'commission-reports';
      case ErpNavSection.financialReports:
        return 'financial-reports';
      case ErpNavSection.chatSupport:
        return 'chat-support';
      case ErpNavSection.settings:
        return 'settings';
    }
  }

  static ErpNavSection? sectionFromPath(String path) {
    final clean = path.replaceAll('#', '').replaceAll('/', '').trim().toLowerCase();
    if (clean.isEmpty) return ErpNavSection.dashboard;
    for (final s in ErpNavSection.values) {
      if (pathToSection(s) == clean || s.name.toLowerCase() == clean.replaceAll('-', '')) {
        return s;
      }
    }
    return null;
  }
}

