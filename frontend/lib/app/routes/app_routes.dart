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
  salesInvoiceList,
  createSale,
  quotations,
  salesOrders,
  salesReturns,
  projectList,
  createProject,
  customerPayments,
  dealerPayments,
  vendorPaymentsSection,
  commissionPayments,
  categoriesUnits,
  vendors,
  customers,
  dealers,
  architects,
  rawMaterials,
  finishedProducts,
  inventoryReports,
  purchaseReports,
  productionReports,
  salesReports,
  projectReports,
  commissionReports,
  financialReports,
  settings,
}

class AppRoutes {
  AppRoutes._();

  static const String login = '/login';
  static const String mainShell = '/app';
}
