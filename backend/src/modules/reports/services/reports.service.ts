import { BadRequestException, Injectable } from '@nestjs/common';
import { DatabasePool } from '../../../core/database/connection';
import { ReportQueryDto } from '../dto/report-query.dto';

@Injectable()
export class ReportsService {
  constructor(private readonly db: DatabasePool) {}

  async getReport(reportType: string, query: ReportQueryDto) {
    switch (reportType) {
      case 'inventory':
        return this.getInventoryReport(query);
      case 'purchase':
        return this.getPurchaseReport(query);
      case 'production':
        return this.getProductionReport(query);
      case 'sales':
        return this.getSalesReport(query);
      case 'project-costing':
      case 'projects':
        return this.getProjectCostingReport(query);
      case 'expenses':
        return this.getExpensesReport(query);
      case 'commissions':
        return this.getCommissionsReport(query);
      case 'financial-balance':
      case 'financial':
        return this.getFinancialBalanceReport(query);
      default:
        throw new BadRequestException(
          `Unknown report type "${reportType}". Valid report types are: inventory, purchase, production, sales, project-costing, expenses, commissions, financial-balance.`,
        );
    }
  }

  // 1. Inventory & Stock Valuation Report
  async getInventoryReport(query: ReportQueryDto) {
    const rawMaterialsRes = await this.db.query<any>(
      `SELECT 
         rm.id,
         rm.name,
         rm.item_code,
         c.name as category_name,
         COALESCE(mu.symbol, 'PCS') as unit,
         COALESCE(rm.current_stock, rm.opening_stock, 0) as current_stock,
         rm.minimum_stock,
         rm.reorder_level,
         rm.default_purchase_price,
         (COALESCE(rm.current_stock, rm.opening_stock, 0) * COALESCE(rm.default_purchase_price, 0)) as valuation
       FROM raw_materials rm
       LEFT JOIN categories c ON c.id = rm.category_id
       LEFT JOIN measurement_units mu ON mu.id = rm.unit_id
       WHERE rm.is_deleted = false
       ORDER BY rm.name ASC`,
    );

    const finishedProductsRes = await this.db.query<any>(
      `SELECT 
         fp.id,
         fp.name,
         fp.item_code,
         c.name as category_name,
         COALESCE(mu.symbol, 'PCS') as unit,
         COALESCE(fp.current_stock, fp.opening_stock, 0) as current_stock,
         fp.cost_price,
         fp.dealer_selling_price,
         fp.customer_selling_price,
         (COALESCE(fp.current_stock, fp.opening_stock, 0) * COALESCE(fp.cost_price, 0)) as valuation
       FROM finished_products fp
       LEFT JOIN categories c ON c.id = fp.category_id
       LEFT JOIN measurement_units mu ON mu.id = fp.unit_id
       WHERE fp.is_deleted = false
       ORDER BY fp.name ASC`,
    );

    const rmRows = rawMaterialsRes.rows.map((r) => ({
      id: r.id,
      name: r.name,
      itemCode: r.item_code,
      itemType: 'rawMaterial',
      category: r.category_name || 'General',
      unit: r.unit,
      currentStock: parseFloat(r.current_stock || '0'),
      unitCost: parseFloat(r.default_purchase_price || '0'),
      valuation: parseFloat(r.valuation || '0'),
      minimumStock: parseFloat(r.minimum_stock || '0'),
    }));

    const fpRows = finishedProductsRes.rows.map((r) => ({
      id: r.id,
      name: r.name,
      itemCode: r.item_code,
      itemType: 'finishedProduct',
      category: r.category_name || 'Lighting Fixtures',
      unit: r.unit,
      currentStock: parseFloat(r.current_stock || '0'),
      unitCost: parseFloat(r.cost_price || '0'),
      dealerPrice: parseFloat(r.dealer_selling_price || '0'),
      customerPrice: parseFloat(r.customer_selling_price || '0'),
      valuation: parseFloat(r.valuation || '0'),
    }));

    const totalRawValuation = rmRows.reduce((acc, x) => acc + x.valuation, 0);
    const totalFinishedValuation = fpRows.reduce((acc, x) => acc + x.valuation, 0);

    return {
      reportType: 'inventory',
      generatedAt: new Date().toISOString(),
      summary: {
        totalRawMaterialItems: rmRows.length,
        totalFinishedProductSkus: fpRows.length,
        totalStockValuation: totalRawValuation + totalFinishedValuation,
        rawMaterialValuation: totalRawValuation,
        finishedProductValuation: totalFinishedValuation,
      },
      rawMaterials: rmRows,
      finishedProducts: fpRows,
    };
  }

  // 2. Purchases Register & Vendor Balances Report
  async getPurchaseReport(query: ReportQueryDto) {
    const conditions: string[] = ['1=1'];
    const params: any[] = [];
    let pIdx = 1;

    if (query.partyId) {
      conditions.push(`p.vendor_id = $${pIdx}`);
      params.push(query.partyId);
      pIdx++;
    }

    if (query.startDate) {
      conditions.push(`p.purchase_date >= $${pIdx}`);
      params.push(query.startDate);
      pIdx++;
    }

    if (query.endDate) {
      conditions.push(`p.purchase_date <= $${pIdx}`);
      params.push(query.endDate);
      pIdx++;
    }

    const whereClause = conditions.join(' AND ');

    const summaryRes = await this.db.query<{
      total_purchases: string;
      total_amount: string;
      taxable_amount: string;
      gst_amount: string;
      paid_amount: string;
      pending_amount: string;
    }>(
      `SELECT 
         COUNT(*) as total_purchases,
         COALESCE(SUM(total_amount), 0) as total_amount,
         COALESCE(SUM(taxable_amount), 0) as taxable_amount,
         COALESCE(SUM(gst_amount), 0) as gst_amount,
         COALESCE(SUM(paid_amount), 0) as paid_amount,
         COALESCE(SUM(pending_amount), 0) as pending_amount
       FROM purchases p
       WHERE ${whereClause}`,
      params,
    );

    const rowsRes = await this.db.query<any>(
      `SELECT 
         p.id,
         p.purchase_number,
         p.purchase_date,
         p.vendor_name,
         p.vendor_invoice_number,
         p.taxable_amount,
         p.cgst_amount,
         p.sgst_amount,
         p.igst_amount,
         p.gst_amount,
         p.total_amount,
         p.paid_amount,
         p.pending_amount,
         p.payment_mode,
         p.status
       FROM purchases p
       WHERE ${whereClause}
       ORDER BY p.purchase_date DESC
       LIMIT 100`,
      params,
    );

    const rows = rowsRes.rows.map((r) => ({
      id: r.id,
      purchaseNumber: r.purchase_number,
      purchaseDate: r.purchase_date,
      vendorName: r.vendor_name,
      vendorInvoiceNumber: r.vendor_invoice_number,
      taxableAmount: parseFloat(r.taxable_amount || '0'),
      cgstAmount: parseFloat(r.cgst_amount || '0'),
      sgstAmount: parseFloat(r.sgst_amount || '0'),
      igstAmount: parseFloat(r.igst_amount || '0'),
      gstAmount: parseFloat(r.gst_amount || '0'),
      totalAmount: parseFloat(r.total_amount || '0'),
      paidAmount: parseFloat(r.paid_amount || '0'),
      pendingAmount: parseFloat(r.pending_amount || '0'),
      paymentMode: r.payment_mode,
      status: r.status,
    }));

    return {
      reportType: 'purchase',
      generatedAt: new Date().toISOString(),
      summary: {
        totalPurchases: parseInt(summaryRes.rows[0]?.total_purchases || '0', 10),
        totalAmount: parseFloat(summaryRes.rows[0]?.total_amount || '0'),
        taxableAmount: parseFloat(summaryRes.rows[0]?.taxable_amount || '0'),
        gstAmount: parseFloat(summaryRes.rows[0]?.gst_amount || '0'),
        paidAmount: parseFloat(summaryRes.rows[0]?.paid_amount || '0'),
        pendingAmount: parseFloat(summaryRes.rows[0]?.pending_amount || '0'),
      },
      records: rows,
    };
  }

  // 3. Production Costing & Manufacturing Output Report
  async getProductionReport(query: ReportQueryDto) {
    const summaryRes = await this.db.query<{
      total_batches: string;
      completed_batches: string;
      total_units_produced: string;
      total_production_cost: string;
      total_raw_material_cost: string;
      total_labour_cost: string;
    }>(
      `SELECT 
         COUNT(*) as total_batches,
         COALESCE(SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END), 0) as completed_batches,
         COALESCE(SUM(COALESCE(actual_quantity_produced, planned_quantity)), 0) as total_units_produced,
         COALESCE(SUM(total_production_cost), 0) as total_production_cost,
         COALESCE(SUM(raw_material_cost), 0) as total_raw_material_cost,
         COALESCE(SUM(labour_cost), 0) as total_labour_cost
       FROM production_orders
       WHERE is_deleted = false`,
    );

    const rowsRes = await this.db.query<any>(
      `SELECT 
         po.id,
         po.production_number as order_number,
         po.finished_product_name,
         po.planned_quantity as target_quantity,
         po.actual_quantity_produced,
         po.unit,
         po.raw_material_cost,
         po.labour_cost,
         po.other_expenses,
         po.total_production_cost as total_cost,
         po.cost_per_unit as unit_cost,
         po.status,
         po.created_at,
         po.production_date as completed_at
       FROM production_orders po
       WHERE po.is_deleted = false
       ORDER BY po.production_date DESC
       LIMIT 100`,
    );

    const rows = rowsRes.rows.map((r) => ({
      id: r.id,
      orderNumber: r.order_number,
      finishedProductName: r.finished_product_name,
      targetQuantity: parseFloat(r.target_quantity || '0'),
      actualQuantityProduced: parseFloat(r.actual_quantity_produced || '0'),
      unit: r.unit,
      rawMaterialCost: parseFloat(r.raw_material_cost || '0'),
      labourCost: parseFloat(r.labour_cost || '0'),
      otherExpenses: parseFloat(r.other_expenses || '0'),
      totalCost: parseFloat(r.total_cost || '0'),
      unitCost: parseFloat(r.unit_cost || '0'),
      status: r.status,
      createdAt: r.created_at,
      completedAt: r.completed_at,
    }));

    return {
      reportType: 'production',
      generatedAt: new Date().toISOString(),
      summary: {
        totalBatches: parseInt(summaryRes.rows[0]?.total_batches || '0', 10),
        completedBatches: parseInt(summaryRes.rows[0]?.completed_batches || '0', 10),
        totalUnitsProduced: parseFloat(summaryRes.rows[0]?.total_units_produced || '0'),
        totalProductionCost: parseFloat(summaryRes.rows[0]?.total_production_cost || '0'),
        totalRawMaterialCost: parseFloat(summaryRes.rows[0]?.total_raw_material_cost || '0'),
        totalLabourCost: parseFloat(summaryRes.rows[0]?.total_labour_cost || '0'),
      },
      records: rows,
    };
  }

  // 4. Sales Revenue & GST Statement Report
  async getSalesReport(query: ReportQueryDto) {
    const conditions: string[] = ["s.document_type = 'invoice'"];
    const params: any[] = [];
    let pIdx = 1;

    if (query.partyId) {
      conditions.push(`s.party_id = $${pIdx}`);
      params.push(query.partyId);
      pIdx++;
    }

    if (query.startDate) {
      conditions.push(`s.sale_date >= $${pIdx}`);
      params.push(query.startDate);
      pIdx++;
    }

    if (query.endDate) {
      conditions.push(`s.sale_date <= $${pIdx}`);
      params.push(query.endDate);
      pIdx++;
    }

    const whereClause = conditions.join(' AND ');

    const summaryRes = await this.db.query<{
      total_invoices: string;
      total_sales_revenue: string;
      taxable_turnover: string;
      cgst_total: string;
      sgst_total: string;
      igst_total: string;
      total_gst_collected: string;
      paid_amount: string;
      pending_receivables: string;
    }>(
      `SELECT 
         COUNT(*) as total_invoices,
         COALESCE(SUM(total_amount), 0) as total_sales_revenue,
         COALESCE(SUM(taxable_amount), 0) as taxable_turnover,
         COALESCE(SUM(cgst_amount), 0) as cgst_total,
         COALESCE(SUM(sgst_amount), 0) as sgst_total,
         COALESCE(SUM(igst_amount), 0) as igst_total,
         COALESCE(SUM(gst_amount), 0) as total_gst_collected,
         COALESCE(SUM(paid_amount), 0) as paid_amount,
         COALESCE(SUM(pending_amount), 0) as pending_receivables
       FROM sales s
       WHERE ${whereClause}`,
      params,
    );

    const rowsRes = await this.db.query<any>(
      `SELECT 
         s.id,
         s.invoice_number,
         s.sale_date,
         s.party_name,
         s.party_type,
         s.taxable_amount,
         s.cgst_amount,
         s.sgst_amount,
         s.igst_amount,
         s.gst_amount,
         s.total_amount,
         s.paid_amount,
         s.pending_amount,
         s.status
       FROM sales s
       WHERE ${whereClause}
       ORDER BY s.sale_date DESC
       LIMIT 100`,
      params,
    );

    const rows = rowsRes.rows.map((r) => ({
      id: r.id,
      invoiceNumber: r.invoice_number,
      saleDate: r.sale_date,
      partyName: r.party_name,
      partyType: r.party_type,
      taxableAmount: parseFloat(r.taxable_amount || '0'),
      cgstAmount: parseFloat(r.cgst_amount || '0'),
      sgstAmount: parseFloat(r.sgst_amount || '0'),
      igstAmount: parseFloat(r.igst_amount || '0'),
      gstAmount: parseFloat(r.gst_amount || '0'),
      roundOff: 0.0,
      totalAmount: parseFloat(r.total_amount || '0'),
      paidAmount: parseFloat(r.paid_amount || '0'),
      pendingAmount: parseFloat(r.pending_amount || '0'),
      status: r.status,
    }));

    return {
      reportType: 'sales',
      generatedAt: new Date().toISOString(),
      summary: {
        totalInvoices: parseInt(summaryRes.rows[0]?.total_invoices || '0', 10),
        totalSalesRevenue: parseFloat(summaryRes.rows[0]?.total_sales_revenue || '0'),
        taxableTurnover: parseFloat(summaryRes.rows[0]?.taxable_turnover || '0'),
        cgstTotal: parseFloat(summaryRes.rows[0]?.cgst_total || '0'),
        sgstTotal: parseFloat(summaryRes.rows[0]?.sgst_total || '0'),
        igstTotal: parseFloat(summaryRes.rows[0]?.igst_total || '0'),
        totalGstCollected: parseFloat(summaryRes.rows[0]?.total_gst_collected || '0'),
        paidAmount: parseFloat(summaryRes.rows[0]?.paid_amount || '0'),
        pendingReceivables: parseFloat(summaryRes.rows[0]?.pending_receivables || '0'),
      },
      records: rows,
    };
  }

  // 5. Project Costing & Profit Margins Report
  async getProjectCostingReport(query: ReportQueryDto) {
    const projectsRes = await this.db.query<any>(
      `SELECT 
         p.id,
         p.project_code,
         p.name,
         p.customer_name,
         p.architect_name,
         p.status,
         p.start_date,
         p.expected_completion_date,
         COALESCE((SELECT SUM(total_amount) FROM sales WHERE project_id = p.id AND document_type = 'invoice'), 0) as total_invoiced,
         COALESCE((SELECT SUM(amount) FROM expenses WHERE project_id = p.id), 0) as total_expenses,
         COALESCE((SELECT SUM(total_production_cost) FROM production_orders WHERE project_id = p.id AND is_deleted = false), 0) as total_material_cost
       FROM projects p
       WHERE p.is_deleted = false
       ORDER BY p.name ASC`,
    );

    const rows = projectsRes.rows.map((r) => {
      const invoiced = parseFloat(r.total_invoiced || '0');
      const expenses = parseFloat(r.total_expenses || '0');
      const materials = parseFloat(r.total_material_cost || '0');
      const totalCost = expenses + materials;
      const profitMargin = invoiced > 0 ? ((invoiced - totalCost) / invoiced) * 100 : 0.0;

      return {
        id: r.id,
        projectCode: r.project_code,
        name: r.name,
        customerName: r.customer_name,
        architectName: r.architect_name,
        status: r.status,
        totalInvoiced: invoiced,
        totalExpenses: expenses,
        materialCost: materials,
        totalCost,
        profitMargin: parseFloat(profitMargin.toFixed(2)),
      };
    });

    const totalTurnover = rows.reduce((acc, x) => acc + x.totalInvoiced, 0);
    const totalCosts = rows.reduce((acc, x) => acc + x.totalCost, 0);

    return {
      reportType: 'project-costing',
      generatedAt: new Date().toISOString(),
      summary: {
        totalProjects: rows.length,
        totalInvoicedTurnover: totalTurnover,
        totalProjectCosts: totalCosts,
        netProjectProfit: totalTurnover - totalCosts,
      },
      records: rows,
    };
  }

  // 6. Expenses Operating Overheads Report
  async getExpensesReport(query: ReportQueryDto) {
    const conditions: string[] = ['1=1'];
    const params: any[] = [];
    let pIdx = 1;

    if (query.category) {
      conditions.push(`e.category = $${pIdx}`);
      params.push(query.category);
      pIdx++;
    }

    if (query.startDate) {
      conditions.push(`e.expense_date >= $${pIdx}`);
      params.push(query.startDate);
      pIdx++;
    }

    if (query.endDate) {
      conditions.push(`e.expense_date <= $${pIdx}`);
      params.push(query.endDate);
      pIdx++;
    }

    const whereClause = conditions.join(' AND ');

    const summaryRes = await this.db.query<{
      total_expense: string;
      transportation: string;
      labour: string;
      utilities: string;
      office: string;
      project: string;
    }>(
      `SELECT 
         COALESCE(SUM(amount), 0) as total_expense,
         COALESCE(SUM(CASE WHEN category IN ('transportation', 'courier', 'fuel') THEN amount ELSE 0 END), 0) as transportation,
         COALESCE(SUM(CASE WHEN category = 'labour' THEN amount ELSE 0 END), 0) as labour,
         COALESCE(SUM(CASE WHEN category IN ('electricity', 'maintenance') THEN amount ELSE 0 END), 0) as utilities,
         COALESCE(SUM(CASE WHEN category = 'officeExpense' THEN amount ELSE 0 END), 0) as office,
         COALESCE(SUM(CASE WHEN category = 'projectExpense' THEN amount ELSE 0 END), 0) as project
       FROM expenses e
       WHERE ${whereClause}`,
      params,
    );

    const rowsRes = await this.db.query<any>(
      `SELECT 
         e.id,
         e.expense_number,
         e.expense_date,
         e.expense_name,
         e.category,
         e.amount,
         e.paid_by,
         e.payment_method,
         e.vendor_payee,
         e.project_name
       FROM expenses e
       WHERE ${whereClause}
       ORDER BY e.expense_date DESC
       LIMIT 100`,
      params,
    );

    const rows = rowsRes.rows.map((r) => ({
      id: r.id,
      expenseNumber: r.expense_number,
      expenseDate: r.expense_date,
      expenseName: r.expense_name,
      category: r.category,
      amount: parseFloat(r.amount || '0'),
      paidBy: r.paid_by,
      paymentMethod: r.payment_method,
      vendorPayee: r.vendor_payee,
      projectName: r.project_name,
    }));

    return {
      reportType: 'expenses',
      generatedAt: new Date().toISOString(),
      summary: {
        totalExpense: parseFloat(summaryRes.rows[0]?.total_expense || '0'),
        transportation: parseFloat(summaryRes.rows[0]?.transportation || '0'),
        labour: parseFloat(summaryRes.rows[0]?.labour || '0'),
        utilities: parseFloat(summaryRes.rows[0]?.utilities || '0'),
        office: parseFloat(summaryRes.rows[0]?.office || '0'),
        project: parseFloat(summaryRes.rows[0]?.project || '0'),
      },
      records: rows,
    };
  }

  // 7. Architect Commissions Statement Report
  async getCommissionsReport(query: ReportQueryDto) {
    const summaryRes = await this.db.query<{
      total_commissions_count: string;
      total_commission_amount: string;
      pending_amount: string;
      approved_amount: string;
      paid_amount: string;
    }>(
      `SELECT 
         COUNT(*) as total_commissions_count,
         COALESCE(SUM(commission_amount), 0) as total_commission_amount,
         COALESCE(SUM(CASE WHEN status = 'generated' THEN commission_amount ELSE 0 END), 0) as pending_amount,
         COALESCE(SUM(CASE WHEN status = 'approved' THEN commission_amount ELSE 0 END), 0) as approved_amount,
         COALESCE(SUM(CASE WHEN status = 'paid' THEN commission_amount ELSE 0 END), 0) as paid_amount
       FROM architect_commissions`,
    );

    const rowsRes = await this.db.query<any>(
      `SELECT 
         c.id,
         c.commission_number,
         c.architect_name,
         c.sale_invoice_number,
         c.project_name,
         c.sale_amount,
         c.commission_rate,
         c.commission_amount,
         c.status,
         c.generated_date,
         c.approved_date,
         c.paid_date
       FROM architect_commissions c
       ORDER BY c.generated_date DESC
       LIMIT 100`,
    );

    const rows = rowsRes.rows.map((r) => ({
      id: r.id,
      commissionNumber: r.commission_number,
      architectName: r.architect_name,
      saleInvoiceNumber: r.sale_invoice_number,
      projectName: r.project_name,
      saleAmount: parseFloat(r.sale_amount || '0'),
      commissionRate: parseFloat(r.commission_rate || '0'),
      commissionAmount: parseFloat(r.commission_amount || '0'),
      status: r.status,
      generatedDate: r.generated_date,
      approvedDate: r.approved_date,
      paidDate: r.paid_date,
    }));

    return {
      reportType: 'commissions',
      generatedAt: new Date().toISOString(),
      summary: {
        totalCommissionsCount: parseInt(summaryRes.rows[0]?.total_commissions_count || '0', 10),
        totalCommissionAmount: parseFloat(summaryRes.rows[0]?.total_commission_amount || '0'),
        pendingCommission: parseFloat(summaryRes.rows[0]?.pending_amount || '0'),
        approvedCommission: parseFloat(summaryRes.rows[0]?.approved_amount || '0'),
        paidCommission: parseFloat(summaryRes.rows[0]?.paid_amount || '0'),
      },
      records: rows,
    };
  }

  // 8. Financial Balance & Working Capital Report
  async getFinancialBalanceReport(query: ReportQueryDto) {
    // Total Sales Revenue
    const salesRes = await this.db.query<{ total: string; pending: string }>(
      `SELECT 
         COALESCE(SUM(total_amount), 0) as total,
         COALESCE(SUM(pending_amount), 0) as pending
       FROM sales 
       WHERE document_type = 'invoice'`,
    );

    // Total Purchases
    const purRes = await this.db.query<{ total: string; pending: string }>(
      `SELECT 
         COALESCE(SUM(total_amount), 0) as total,
         COALESCE(SUM(pending_amount), 0) as pending
       FROM purchases`,
    );

    // Total Expenses
    const expRes = await this.db.query<{ total: string }>(
      `SELECT COALESCE(SUM(amount), 0) as total FROM expenses`,
    );

    // Customer Receivables
    const custRes = await this.db.query<{ total: string }>(
      `SELECT COALESCE(SUM(outstanding_amount), 0) as total FROM customers WHERE is_deleted = false`,
    );

    // Dealer Receivables
    const dealRes = await this.db.query<{ total: string }>(
      `SELECT COALESCE(SUM(outstanding_amount), 0) as total FROM dealers WHERE is_deleted = false`,
    );

    // Vendor Payables
    const vendRes = await this.db.query<{ total: string }>(
      `SELECT COALESCE(SUM(outstanding_balance), 0) as total FROM vendors WHERE is_deleted = false`,
    );

    const totalSales = parseFloat(salesRes.rows[0]?.total || '0');
    const totalPurchases = parseFloat(purRes.rows[0]?.total || '0');
    const totalExpenses = parseFloat(expRes.rows[0]?.total || '0');
    const customerOutstanding = parseFloat(custRes.rows[0]?.total || '0');
    const dealerOutstanding = parseFloat(dealRes.rows[0]?.total || '0');
    const vendorOutstanding = parseFloat(vendRes.rows[0]?.total || '0');

    const totalReceivables = customerOutstanding + dealerOutstanding;
    const totalPayables = vendorOutstanding;
    const workingCapital = totalReceivables - totalPayables;

    return {
      reportType: 'financial-balance',
      generatedAt: new Date().toISOString(),
      summary: {
        totalSalesRevenue: totalSales,
        totalPurchases: totalPurchases,
        totalExpenses: totalExpenses,
        netCashFlowEstimate: totalSales - (totalPurchases + totalExpenses),
        totalReceivables,
        totalPayables,
        workingCapitalEstimate: workingCapital,
        customerOutstanding,
        dealerOutstanding,
        vendorOutstanding,
      },
    };
  }
}
