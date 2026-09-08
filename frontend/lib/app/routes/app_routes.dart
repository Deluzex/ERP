enum ErpNavSection {
  dashboard,
  inventoryDashboard,
  rawMaterialStock,
  finishedProductStock,
  stockMovement,
  stockAdjustments,
  purchaseList,
  createPurchase,
  purchaseHistory,
  vendorPayments,
  productionOrders,
  createProduction,
  productionHistory,
  productionCosting,
  // Sales Module
  salesDashboard,
  quotations,
  createQuotation,
  proformaInvoices,
  salesOrders,
  createSalesOrder,
  salesDeliveries,
  salesInvoiceList,
  createSale,
  salesReturns,
  createSalesReturn,
  // Projects
  projectList,
  createProject,
  // Payments
  customerPayments,
  dealerPayments,
  vendorPaymentsSection,
  commissionPayments,
  // Masters
  categoriesUnits,
  vendors,
  customers,
  dealers,
  architects,
  rawMaterials,
  finishedProducts,
  // Reports
  inventoryReports,
  purchaseReports,
  productionReports,
  salesReports,
  projectReports,
  commissionReports,
  financialReports,
  // Settings
  settings,
}

class AppRoutes {
  AppRoutes._();

  static const String login = '/login';
  static const String mainShell = '/app';
}
