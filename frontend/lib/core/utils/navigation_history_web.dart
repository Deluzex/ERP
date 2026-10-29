// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/routes/app_routes.dart';
import '../../shared/providers/app_state_providers.dart';

/// Web implementation of NavigationHistory using browser session history.
/// Connects browser Back (<-) & Forward (->) arrows to Riverpod navigation state.
class NavigationHistory {
  NavigationHistory._();

  static final List<ErpNavSection> _historyStack = [];
  static WidgetRef? _ref;
  static GlobalKey<NavigatorState>? _navigatorKey;
  static bool _isHandlingPopState = false;
  static bool _initialized = false;
  static dynamic _popStateSubscription;

  static bool get canGoBack => _historyStack.length > 1;

  static void initialize(WidgetRef ref, {GlobalKey<NavigatorState>? navigatorKey}) {
    _ref = ref;
    _navigatorKey = navigatorKey;
    if (_initialized) return;
    _initialized = true;

    _historyStack.clear();

    // Check if user loaded the page with a specific URL hash (e.g. #/production-invoices)
    final currentHash = html.window.location.hash;
    final initialFromHash = sectionFromPath(currentHash);

    final ErpNavSection initialSection =
        initialFromHash ?? ref.read(currentNavSectionProvider);
    _historyStack.add(initialSection);

    if (initialFromHash != null) {
      ref.read(currentNavSectionProvider.notifier).state = initialSection;
    }

    try {
      html.window.history.replaceState(
        {'section': initialSection.name},
        initialSection.name,
        '#/${pathToSection(initialSection)}',
      );
    } catch (_) {}

    // Listen to browser Back and Forward button events
    _popStateSubscription = html.window.onPopState.listen((event) {
      if (_ref == null) return;

      // 1. If an active modal dialog / route can be popped via Navigator, pop it
      final nav = _navigatorKey?.currentState;
      if (nav != null && nav.canPop()) {
        nav.pop();
        return;
      }

      // 2. If a drilldown detail view is currently active, pop it
      final detailStack = _ref!.read(activeRecordDetailsStackProvider);
      if (detailStack.isNotEmpty) {
        _ref!.read(activeRecordDetailsStackProvider.notifier).pop();
        return;
      }

      // 3. Extract target section from event state or location hash
      final state = event.state;
      ErpNavSection? targetSection;

      if (state is Map && state['section'] != null) {
        for (final s in ErpNavSection.values) {
          if (s.name == state['section'].toString()) {
            targetSection = s;
            break;
          }
        }
      }

      targetSection ??= sectionFromPath(html.window.location.hash);

      if (targetSection != null) {
        _isHandlingPopState = true;
        try {
          if (_historyStack.isNotEmpty) {
            final idx = _historyStack.lastIndexOf(targetSection);
            if (idx != -1) {
              _historyStack.removeRange(idx + 1, _historyStack.length);
            } else {
              _historyStack.add(targetSection);
            }
          }
          _ref!.read(currentNavSectionProvider.notifier).state = targetSection;
        } finally {
          _isHandlingPopState = false;
        }
      }
    });
  }

  static void onSectionChanged(ErpNavSection section) {
    if (_isHandlingPopState) return;

    if (_historyStack.isNotEmpty && _historyStack.last == section) {
      return;
    }

    _historyStack.add(section);

    try {
      final targetPath = '#/${pathToSection(section)}';
      if (html.window.location.hash != targetPath) {
        html.window.history.pushState(
          {'section': section.name},
          section.name,
          targetPath,
        );
      }
    } catch (_) {}
  }

  static void onDetailStateChanged(bool isDetailOpen, ErpNavSection currentSection) {
    if (_isHandlingPopState) return;

    try {
      if (isDetailOpen) {
        html.window.history.pushState(
          {'isDetail': true, 'section': currentSection.name},
          'Details',
          '#/${pathToSection(currentSection)}/details',
        );
      }
    } catch (_) {}
  }

  static bool goBack() {
    try {
      html.window.history.back();
      return true;
    } catch (_) {
      if (_historyStack.length > 1 && _ref != null) {
        _historyStack.removeLast();
        final prev = _historyStack.last;
        _ref!.read(currentNavSectionProvider.notifier).state = prev;
        return true;
      }
      return false;
    }
  }

  static void dispose() {
    try {
      _popStateSubscription?.cancel();
    } catch (_) {}
    _initialized = false;
    _ref = null;
    _navigatorKey = null;
    _isHandlingPopState = false;
    _historyStack.clear();
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

