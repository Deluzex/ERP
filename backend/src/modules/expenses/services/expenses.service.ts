import { Injectable } from '@nestjs/common';
import { AuditService } from '../../../core/audit/audit.service';
import { DatabasePool } from '../../../core/database/connection';
import { NotFoundError } from '../../../core/errors/not-found.error';
import { CreateExpenseDto } from '../dto/create-expense.dto';
import { ExpenseQueryDto } from '../dto/expense-query.dto';
import { UpdateExpenseDto } from '../dto/update-expense.dto';

@Injectable()
export class ExpensesService {
  constructor(
    private readonly db: DatabasePool,
    private readonly auditService: AuditService,
  ) {}

  // --------------------------------------------------------------------------
  // List Expenses
  // --------------------------------------------------------------------------
  async findAll(query: ExpenseQueryDto) {
    const page = Math.max(1, query.page || 1);
    const limit = Math.max(1, query.limit || 50);
    const offset = (page - 1) * limit;

    const conditions: string[] = ['1=1'];
    const params: any[] = [];
    let pIdx = 1;

    if (query.category) {
      conditions.push(`e.category = $${pIdx}`);
      params.push(query.category);
      pIdx++;
    }

    if (query.projectId) {
      conditions.push(`e.project_id = $${pIdx}`);
      params.push(query.projectId);
      pIdx++;
    }

    if (query.paymentStatus) {
      conditions.push(`e.payment_status = $${pIdx}`);
      params.push(query.paymentStatus);
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

    if (query.search) {
      conditions.push(
        `(e.expense_number ILIKE $${pIdx} OR e.expense_name ILIKE $${pIdx} OR e.vendor_payee ILIKE $${pIdx} OR e.description ILIKE $${pIdx} OR e.expense_reference ILIKE $${pIdx})`,
      );
      params.push(`%${query.search}%`);
      pIdx++;
    }

    const whereClause = conditions.join(' AND ');

    // Total Count
    const countRes = await this.db.query<{ count: string }>(
      `SELECT COUNT(*) as count FROM expenses e WHERE ${whereClause}`,
      params,
    );
    const total = parseInt(countRes.rows[0]?.count || '0', 10);

    // Summary Totals
    const summaryRes = await this.db.query<{
      total_expense: string;
      transportation_total: string;
      labour_total: string;
      utilities_total: string;
    }>(
      `SELECT 
         COALESCE(SUM(amount), 0) as total_expense,
         COALESCE(SUM(CASE WHEN category IN ('transportation', 'courier', 'fuel') THEN amount ELSE 0 END), 0) as transportation_total,
         COALESCE(SUM(CASE WHEN category = 'labour' THEN amount ELSE 0 END), 0) as labour_total,
         COALESCE(SUM(CASE WHEN category IN ('electricity', 'maintenance') THEN amount ELSE 0 END), 0) as utilities_total
       FROM expenses e
       WHERE ${whereClause}`,
      params,
    );

    // Query Data
    const dataRes = await this.db.query<any>(
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
         e.project_id,
         e.project_name,
         e.purchase_id,
         e.purchase_number,
         e.production_id,
         e.production_number,
         e.expense_reference,
         e.description,
         e.receipt_attachment_name,
         e.payment_status,
         e.created_by,
         e.created_at,
         e.updated_at
       FROM expenses e
       WHERE ${whereClause}
       ORDER BY e.expense_date DESC, e.created_at DESC
       LIMIT $${pIdx} OFFSET $${pIdx + 1}`,
      [...params, limit, offset],
    );

    return {
      data: dataRes.rows.map(this.mapExpenseRow),
      meta: {
        total,
        page,
        limit,
        totalPages: Math.ceil(total / limit),
        summary: {
          totalExpense: summaryRes.rows[0]?.total_expense || '0.00',
          transportationTotal: summaryRes.rows[0]?.transportation_total || '0.00',
          labourTotal: summaryRes.rows[0]?.labour_total || '0.00',
          utilitiesTotal: summaryRes.rows[0]?.utilities_total || '0.00',
        },
      },
    };
  }

  // --------------------------------------------------------------------------
  // Get Expense by ID
  // --------------------------------------------------------------------------
  async findById(id: string) {
    const res = await this.db.query<any>(
      `SELECT * FROM expenses WHERE id = $1`,
      [id],
    );
    if (!res.rows.length) {
      throw new NotFoundError(`Expense with ID "${id}" was not found`);
    }
    return this.mapExpenseRow(res.rows[0]);
  }

  // --------------------------------------------------------------------------
  // Create Expense Voucher
  // --------------------------------------------------------------------------
  async create(dto: CreateExpenseDto, userId?: string, correlationId?: string) {
    // Generate sequential expense number
    const seqRes = await this.db.query<{ nextval: string }>(
      `SELECT nextval('seq_expense_number') as nextval`,
    );
    const seq = seqRes.rows[0].nextval;
    const year = new Date().getFullYear();
    const expenseNumber = `EXP-${year}-${seq.padStart(4, '0')}`;

    const res = await this.db.query<any>(
      `INSERT INTO expenses (
         expense_number,
         expense_date,
         expense_name,
         category,
         amount,
         paid_by,
         payment_method,
         vendor_payee,
         project_id,
         project_name,
         purchase_id,
         purchase_number,
         production_id,
         production_number,
         expense_reference,
         description,
         receipt_attachment_name,
         payment_status,
         created_by
       )
       VALUES ($1, COALESCE($2, now()), $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, COALESCE($18, 'paid'), $19)
       RETURNING *`,
      [
        expenseNumber,
        dto.expenseDate || null,
        dto.expenseName,
        dto.category,
        dto.amount,
        dto.paidBy,
        dto.paymentMethod,
        dto.vendorPayee || null,
        dto.projectId || null,
        dto.projectName || null,
        dto.purchaseId || null,
        dto.purchaseNumber || null,
        dto.productionId || null,
        dto.productionNumber || null,
        dto.expenseReference || null,
        dto.description || null,
        dto.receiptAttachmentName || null,
        dto.paymentStatus || 'paid',
        dto.paidBy || 'Admin',
      ],
    );
    const expense = res.rows[0];

    // Audit Log
    await this.auditService.record({
      userId,
      action: 'CREATE',
      entityType: 'expense',
      entityId: expense.id,
      afterSnapshot: expense,
      correlationId,
    });

    return this.mapExpenseRow(expense);
  }

  // --------------------------------------------------------------------------
  // Update Expense Voucher
  // --------------------------------------------------------------------------
  async update(
    id: string,
    dto: UpdateExpenseDto,
    userId?: string,
    correlationId?: string,
  ) {
    const existingRes = await this.db.query<any>(
      `SELECT * FROM expenses WHERE id = $1`,
      [id],
    );
    if (!existingRes.rows.length) {
      throw new NotFoundError(`Expense with ID "${id}" was not found`);
    }
    const existing = existingRes.rows[0];

    const res = await this.db.query<any>(
      `UPDATE expenses
       SET expense_name = COALESCE($1, expense_name),
           category = COALESCE($2, category),
           amount = COALESCE($3, amount),
           expense_date = COALESCE($4, expense_date),
           paid_by = COALESCE($5, paid_by),
           payment_method = COALESCE($6, payment_method),
           vendor_payee = COALESCE($7, vendor_payee),
           project_id = COALESCE($8, project_id),
           project_name = COALESCE($9, project_name),
           expense_reference = COALESCE($10, expense_reference),
           description = COALESCE($11, description),
           payment_status = COALESCE($12, payment_status),
           updated_at = now()
       WHERE id = $13
       RETURNING *`,
      [
        dto.expenseName || null,
        dto.category || null,
        dto.amount !== undefined ? dto.amount : null,
        dto.expenseDate || null,
        dto.paidBy || null,
        dto.paymentMethod || null,
        dto.vendorPayee || null,
        dto.projectId || null,
        dto.projectName || null,
        dto.expenseReference || null,
        dto.description || null,
        dto.paymentStatus || null,
        id,
      ],
    );
    const updated = res.rows[0];

    // Audit Log
    await this.auditService.record({
      userId,
      action: 'UPDATE',
      entityType: 'expense',
      entityId: id,
      beforeSnapshot: existing,
      afterSnapshot: updated,
      correlationId,
    });

    return this.mapExpenseRow(updated);
  }

  // --------------------------------------------------------------------------
  // Delete Expense Voucher
  // --------------------------------------------------------------------------
  async delete(id: string, userId?: string, correlationId?: string) {
    const existingRes = await this.db.query<any>(
      `SELECT * FROM expenses WHERE id = $1`,
      [id],
    );
    if (!existingRes.rows.length) {
      throw new NotFoundError(`Expense with ID "${id}" was not found`);
    }
    const existing = existingRes.rows[0];

    await this.db.query(`DELETE FROM expenses WHERE id = $1`, [id]);

    // Audit Log
    await this.auditService.record({
      userId,
      action: 'DELETE',
      entityType: 'expense',
      entityId: id,
      beforeSnapshot: existing,
      correlationId,
    });

    return { success: true, message: `Expense voucher "${existing.expense_number}" deleted successfully` };
  }

  private mapExpenseRow(row: any) {
    return {
      id: row.id,
      expenseNumber: row.expense_number,
      expenseDate: row.expense_date,
      expenseName: row.expense_name,
      category: row.category,
      amount: parseFloat(row.amount || '0'),
      paidBy: row.paid_by,
      paymentMethod: row.payment_method,
      vendorPayee: row.vendor_payee,
      projectId: row.project_id,
      projectName: row.project_name,
      purchaseId: row.purchase_id,
      purchaseNumber: row.purchase_number,
      productionId: row.production_id,
      productionNumber: row.production_number,
      expenseReference: row.expense_reference,
      description: row.description,
      receiptAttachmentName: row.receipt_attachment_name,
      paymentStatus: row.payment_status,
      createdBy: row.created_by,
      createdAt: row.created_at,
      updatedAt: row.updated_at,
    };
  }
}
