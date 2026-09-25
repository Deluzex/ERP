enum ErpNavSection {
  dashboard,
  // 1. Inventory Module
  inventoryDashboard,
  rawMaterialStock,
  finishedProductStock,
  stockMovement,
  stockAdjustments,
  // 2. Purchase Module
  purchaseDashboard,
  purchaseList,
  createPurchase,
  purchaseHistory,
  vendorPayments,
  // 3. Production Module
  productionDashboard,
  productionOrders,
  createProduction,
  productionHistory,
  productionCosting,
  // 4. Sales Module
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
  // 5. Payments & Expenses
  paymentsDashboard,
  customerPayments,
  dealerPayments,
  vendorPaymentsSection,
  commissionPayments,
  expenseList,
  // 6. Masters
  mastersDashboard,
  categoriesUnits,
  vendors,
  customers,
  dealers,
  architects,
  rawMaterials,
  finishedProducts,
  // 7. Reports
  reportsDashboard,
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
