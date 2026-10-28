import { Injectable, NotFoundException } from '@nestjs/common';
import { AuditService } from '../../../core/audit/audit.service';
import { DatabasePool } from '../../../core/database/connection';
import {
  CreateProjectDto,
  ProjectQueryDto,
  UpdateProjectDto,
} from '../dto/projects.dto';

@Injectable()
export class ProjectsService {
  constructor(
    private readonly db: DatabasePool,
    private readonly auditService: AuditService,
  ) {}

  async findAll(query: ProjectQueryDto) {
    const conditions: string[] = ['p.is_deleted = false'];
    const params: any[] = [];
    let paramIndex = 1;

    if (query.search) {
      conditions.push(
        `(p.name ILIKE $${paramIndex} OR p.project_code ILIKE $${paramIndex} OR p.customer_name ILIKE $${paramIndex} OR p.architect_name ILIKE $${paramIndex} OR p.notes ILIKE $${paramIndex})`,
      );
      params.push(`%${query.search.trim()}%`);
      paramIndex++;
    }

    if (query.status) {
      conditions.push(`p.status = $${paramIndex}`);
      params.push(query.status);
      paramIndex++;
    }

    if (query.customerId) {
      conditions.push(`p.customer_id = $${paramIndex}`);
      params.push(query.customerId);
      paramIndex++;
    }

    if (query.architectId) {
      conditions.push(`p.architect_id = $${paramIndex}`);
      params.push(query.architectId);
      paramIndex++;
    }

    if (query.dealerId) {
      conditions.push(`p.dealer_id = $${paramIndex}`);
      params.push(query.dealerId);
      paramIndex++;
    }

    const whereClause = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';

    // KPIs & Aggregations
    const kpiRes = await this.db.query<{
      total_count: string;
      active_count: string;
      completed_count: string;
      total_budget: string;
    }>(
      `SELECT
        COUNT(*)::text as total_count,
        COUNT(CASE WHEN p.status = 'active' THEN 1 END)::text as active_count,
        COUNT(CASE WHEN p.status = 'completed' THEN 1 END)::text as completed_count,
        COALESCE(SUM(p.budget_amount), 0)::text as total_budget
       FROM projects p
       ${whereClause}`,
      params,
    );

    const page = query.page && query.page > 0 ? query.page : 1;
    const limit = query.limit && query.limit > 0 ? query.limit : 50;
    const offset = (page - 1) * limit;

    const listParams = [...params, limit, offset];
    const dataRes = await this.db.query<any>(
      `SELECT
        p.id,
        p.project_code,
        p.name,
        p.customer_id,
        p.customer_name,
        p.dealer_id,
        p.dealer_name,
        p.architect_id,
        p.architect_name,
        p.start_date,
        p.expected_completion_date,
        p.actual_completion_date,
        p.status,
        p.budget_amount::float as budget_amount,
        COALESCE(
          (SELECT SUM(s.total_amount) FROM sales s WHERE s.project_id = p.id AND s.document_type = 'invoice' AND s.status != 'cancelled'),
          p.total_sales_amount,
          0
        )::float as total_sales_amount,
        COALESCE(
          (SELECT SUM(s.architect_commission_amount) FROM sales s WHERE s.project_id = p.id AND s.document_type = 'invoice' AND s.status != 'cancelled'),
          p.total_commission_amount,
          0
        )::float as total_commission_amount,
        p.site_state,
        p.site_state_code,
        p.site_address,
        p.site_pincode,
        p.pos_verified,
        p.notes,
        p.created_at,
        p.updated_at
       FROM projects p
       ${whereClause}
       ORDER BY p.created_at DESC
       LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`,
      listParams,
    );

    const kpi = kpiRes.rows[0];
    const totalRecords = parseInt(kpi?.total_count || '0', 10);

    return {
      data: dataRes.rows.map(this.mapRow),
      meta: {
        total: totalRecords,
        page,
        limit,
        totalPages: Math.ceil(totalRecords / limit),
        kpis: {
          totalProjects: totalRecords,
          activeProjects: parseInt(kpi?.active_count || '0', 10),
          completedProjects: parseInt(kpi?.completed_count || '0', 10),
          totalBudget: parseFloat(kpi?.total_budget || '0'),
        },
      },
    };
  }

  async findById(id: string) {
    const res = await this.db.query<any>(
      `SELECT
        p.id,
        p.project_code,
        p.name,
        p.customer_id,
        p.customer_name,
        p.dealer_id,
        p.dealer_name,
        p.architect_id,
        p.architect_name,
        p.start_date,
        p.expected_completion_date,
        p.actual_completion_date,
        p.status,
        p.budget_amount::float as budget_amount,
        COALESCE(
          (SELECT SUM(s.total_amount) FROM sales s WHERE s.project_id = p.id AND s.document_type = 'invoice' AND s.status != 'cancelled'),
          p.total_sales_amount,
          0
        )::float as total_sales_amount,
        COALESCE(
          (SELECT SUM(s.architect_commission_amount) FROM sales s WHERE s.project_id = p.id AND s.document_type = 'invoice' AND s.status != 'cancelled'),
          p.total_commission_amount,
          0
        )::float as total_commission_amount,
        p.site_state,
        p.site_state_code,
        p.site_address,
        p.site_pincode,
        p.pos_verified,
        p.notes,
        p.created_at,
        p.updated_at
       FROM projects p
       WHERE p.id = $1 AND p.is_deleted = false`,
      [id],
    );

    if (res.rows.length === 0) {
      throw new NotFoundException(`Project with ID ${id} not found`);
    }

    return this.mapRow(res.rows[0]);
  }

  async create(dto: CreateProjectDto, userId?: string, correlationId?: string) {
    // Generate sequential project code
    const year = new Date().getFullYear();
    const countRes = await this.db.query<{ count: string }>(
      `SELECT count(*)::text as count FROM projects WHERE project_code LIKE $1`,
      [`PRJ-${year}-%`],
    );
    const seq = (parseInt(countRes.rows[0]?.count || '0', 10) + 1).toString().padStart(4, '0');
    const projectCode = `PRJ-${year}-${seq}`;

    // Resolve party names if IDs provided
    let customerName: string | null = null;
    if (dto.customerId) {
      const cRes = await this.db.query<{ name: string }>(
        `SELECT name FROM customers WHERE id = $1 AND is_deleted = false`,
        [dto.customerId],
      );
      customerName = cRes.rows[0]?.name || null;
    }

    let dealerName: string | null = null;
    if (dto.dealerId) {
      const dRes = await this.db.query<{ name: string; company_name: string }>(
        `SELECT COALESCE(company_name, name) as name FROM dealers WHERE id = $1 AND is_deleted = false`,
        [dto.dealerId],
      );
      dealerName = dRes.rows[0]?.name || null;
    }

    let architectName: string | null = null;
    if (dto.architectId) {
      const aRes = await this.db.query<{ name: string }>(
        `SELECT name FROM architects WHERE id = $1 AND is_deleted = false`,
        [dto.architectId],
      );
      architectName = aRes.rows[0]?.name || null;
    }

    const startDate = dto.startDate || new Date().toISOString().split('T')[0];
    const status = dto.status || 'active';
    const budgetAmount = dto.budgetAmount || 0;
    const siteState = dto.siteState?.trim() || null;
    const siteStateCode = dto.siteStateCode?.trim() || (siteState?.toLowerCase() === 'gujarat' ? '24' : (siteState?.toLowerCase() === 'maharashtra' ? '27' : null));
    const siteAddress = dto.siteAddress?.trim() || null;
    const sitePincode = dto.sitePincode?.trim() || null;
    const posVerified = dto.posVerified !== undefined ? dto.posVerified : Boolean(siteState);

    const res = await this.db.query<any>(
      `INSERT INTO projects (
        project_code, name, customer_id, customer_name,
        dealer_id, dealer_name, architect_id, architect_name,
        start_date, expected_completion_date, status,
        budget_amount, site_state, site_state_code, site_address, site_pincode, pos_verified,
        notes, created_by, created_at, updated_at
      ) VALUES (
        $1, $2, $3, $4,
        $5, $6, $7, $8,
        $9, $10, $11,
        $12, $13, $14, $15, $16, $17,
        $18, $19, now(), now()
      )
      RETURNING *`,
      [
        projectCode,
        dto.name.trim(),
        dto.customerId || null,
        customerName,
        dto.dealerId || null,
        dealerName,
        dto.architectId || null,
        architectName,
        startDate,
        dto.expectedCompletionDate || null,
        status,
        budgetAmount,
        siteState,
        siteStateCode,
        siteAddress,
        sitePincode,
        posVerified,
        dto.notes?.trim() || null,
        userId || null,
      ],
    );

    const project = this.mapRow(res.rows[0]);

    await this.auditService.record({
      userId,
      action: 'projects.create',
      entityType: 'projects',
      entityId: project.id,
      afterSnapshot: project,
      correlationId,
    });

    return project;
  }

  async update(id: string, dto: UpdateProjectDto, userId?: string, correlationId?: string) {
    const existing = await this.findById(id);

    // Resolve updated party names if party IDs changed
    let customerName = existing.customerName;
    if (dto.customerId !== undefined) {
      if (dto.customerId) {
        const cRes = await this.db.query<{ name: string }>(
          `SELECT name FROM customers WHERE id = $1 AND is_deleted = false`,
          [dto.customerId],
        );
        customerName = cRes.rows[0]?.name || null;
      } else {
        customerName = null;
      }
    }

    let dealerName = existing.dealerName;
    if (dto.dealerId !== undefined) {
      if (dto.dealerId) {
        const dRes = await this.db.query<{ name: string; company_name: string }>(
          `SELECT COALESCE(company_name, name) as name FROM dealers WHERE id = $1 AND is_deleted = false`,
          [dto.dealerId],
        );
        dealerName = dRes.rows[0]?.name || null;
      } else {
        dealerName = null;
      }
    }

    let architectName = existing.architectName;
    if (dto.architectId !== undefined) {
      if (dto.architectId) {
        const aRes = await this.db.query<{ name: string }>(
          `SELECT name FROM architects WHERE id = $1 AND is_deleted = false`,
          [dto.architectId],
        );
        architectName = aRes.rows[0]?.name || null;
      } else {
        architectName = null;
      }
    }

    const hasSiteState = dto.siteState !== undefined;
    const siteState = dto.siteState ? dto.siteState.trim() : null;
    const hasSiteStateCode = dto.siteStateCode !== undefined;
    const siteStateCode = hasSiteStateCode
      ? (dto.siteStateCode ? dto.siteStateCode.trim() : null)
      : (hasSiteState && siteState ? (siteState.toLowerCase() === 'gujarat' ? '24' : (siteState.toLowerCase() === 'maharashtra' ? '27' : null)) : null);
    const hasSiteAddress = dto.siteAddress !== undefined;
    const siteAddress = dto.siteAddress ? dto.siteAddress.trim() : null;
    const hasSitePincode = dto.sitePincode !== undefined;
    const sitePincode = dto.sitePincode ? dto.sitePincode.trim() : null;
    const hasPosVerified = dto.posVerified !== undefined;
    const posVerified = dto.posVerified ?? false;

    const res = await this.db.query<any>(
      `UPDATE projects SET
        name = COALESCE($1, name),
        customer_id = CASE WHEN $2::boolean THEN $3 ELSE customer_id END,
        customer_name = CASE WHEN $2::boolean THEN $4 ELSE customer_name END,
        dealer_id = CASE WHEN $5::boolean THEN $6 ELSE dealer_id END,
        dealer_name = CASE WHEN $5::boolean THEN $7 ELSE dealer_name END,
        architect_id = CASE WHEN $8::boolean THEN $9 ELSE architect_id END,
        architect_name = CASE WHEN $8::boolean THEN $10 ELSE architect_name END,
        start_date = COALESCE($11, start_date),
        expected_completion_date = CASE WHEN $12::boolean THEN $13 ELSE expected_completion_date END,
        actual_completion_date = CASE WHEN $14::boolean THEN $15 ELSE actual_completion_date END,
        status = COALESCE($16, status),
        budget_amount = COALESCE($17, budget_amount),
        site_state = CASE WHEN $18::boolean THEN $19 ELSE site_state END,
        site_state_code = CASE WHEN $20::boolean THEN $21 ELSE site_state_code END,
        site_address = CASE WHEN $22::boolean THEN $23 ELSE site_address END,
        site_pincode = CASE WHEN $24::boolean THEN $25 ELSE site_pincode END,
        pos_verified = CASE WHEN $26::boolean THEN $27 ELSE pos_verified END,
        notes = CASE WHEN $28::boolean THEN $29 ELSE notes END,
        updated_at = now()
      WHERE id = $30 AND is_deleted = false
      RETURNING *`,
      [
        dto.name?.trim() || null,
        dto.customerId !== undefined,
        dto.customerId || null,
        customerName,
        dto.dealerId !== undefined,
        dto.dealerId || null,
        dealerName,
        dto.architectId !== undefined,
        dto.architectId || null,
        architectName,
        dto.startDate || null,
        dto.expectedCompletionDate !== undefined,
        dto.expectedCompletionDate || null,
        dto.actualCompletionDate !== undefined,
        dto.actualCompletionDate || null,
        dto.status || null,
        dto.budgetAmount !== undefined ? dto.budgetAmount : null,
        hasSiteState,
        siteState,
        hasSiteState || hasSiteStateCode,
        siteStateCode,
        hasSiteAddress,
        siteAddress,
        hasSitePincode,
        sitePincode,
        hasPosVerified,
        posVerified,
        dto.notes !== undefined,
        dto.notes ? dto.notes.trim() : null,
        id,
      ],
    );

    const updated = this.mapRow(res.rows[0]);

    await this.auditService.record({
      userId,
      action: 'projects.edit',
      entityType: 'projects',
      entityId: id,
      beforeSnapshot: existing,
      afterSnapshot: updated,
      correlationId,
    });

    return updated;
  }

  async delete(id: string, reason: string, userId?: string, correlationId?: string) {
    const existing = await this.findById(id);

    await this.db.query(
      `UPDATE projects SET
        is_deleted = true,
        deleted_at = now(),
        delete_reason = $1,
        updated_at = now()
      WHERE id = $2`,
      [reason, id],
    );

    await this.auditService.record({
      userId,
      action: 'projects.delete',
      entityType: 'projects',
      entityId: id,
      beforeSnapshot: existing,
      reason,
      correlationId,
    });

    return { message: 'Project soft-deleted successfully', id };
  }

  async getFinancials(id: string) {
    const project = await this.findById(id);

    // Sales turnover
    const salesRes = await this.db.query<{ count: string; total_sales: string }>(
      `SELECT
        COUNT(*)::text as count,
        COALESCE(SUM(total_amount), 0)::text as total_sales
       FROM sales
       WHERE project_id = $1 AND status != 'cancelled'`,
      [id],
    );

    // Purchase procurement spend
    const purchaseRes = await this.db.query<{ count: string; total_purchases: string }>(
      `SELECT
        COUNT(*)::text as count,
        COALESCE(SUM(total_amount), 0)::text as total_purchases
       FROM purchases
       WHERE project_id = $1 AND status != 'cancelled'`,
      [id],
    );

    // Production work orders
    const prodRes = await this.db.query<{ count: string; completed_count: string }>(
      `SELECT
        COUNT(*)::text as count,
        COUNT(CASE WHEN status = 'completed' THEN 1 END)::text as completed_count
       FROM production_orders
       WHERE project_id = $1 AND status != 'cancelled'`,
      [id],
    );

    const totalSales = parseFloat(salesRes.rows[0]?.total_sales || '0');
    const totalPurchases = parseFloat(purchaseRes.rows[0]?.total_purchases || '0');
    const budgetAmount = project.budgetAmount || 0;
    const netMargin = totalSales - totalPurchases;

    return {
      projectId: id,
      projectCode: project.projectCode,
      name: project.name,
      status: project.status,
      budgetAmount,
      totalSalesAmount: totalSales,
      totalPurchaseCost: totalPurchases,
      netMargin,
      salesCount: parseInt(salesRes.rows[0]?.count || '0', 10),
      purchaseCount: parseInt(purchaseRes.rows[0]?.count || '0', 10),
      productionOrdersCount: parseInt(prodRes.rows[0]?.count || '0', 10),
      productionOrdersCompleted: parseInt(prodRes.rows[0]?.completed_count || '0', 10),
    };
  }

  private mapRow(row: any) {
    return {
      id: row.id,
      projectCode: row.project_code,
      name: row.name,
      customerId: row.customer_id,
      customerName: row.customer_name,
      dealerId: row.dealer_id,
      dealerName: row.dealer_name,
      architectId: row.architect_id,
      architectName: row.architect_name,
      startDate: row.start_date,
      expectedCompletionDate: row.expected_completion_date,
      actualCompletionDate: row.actual_completion_date,
      status: row.status,
      budgetAmount: typeof row.budget_amount === 'number' ? row.budget_amount : parseFloat(row.budget_amount || '0'),
      totalSalesAmount: typeof row.total_sales_amount === 'number' ? row.total_sales_amount : parseFloat(row.total_sales_amount || '0'),
      totalCommissionAmount: typeof row.total_commission_amount === 'number' ? row.total_commission_amount : parseFloat(row.total_commission_amount || '0'),
      siteState: row.site_state || null,
      siteStateCode: row.site_state_code || null,
      siteAddress: row.site_address || null,
      sitePincode: row.site_pincode || null,
      posVerified: row.pos_verified ?? false,
      notes: row.notes,
      createdAt: row.created_at,
      updatedAt: row.updated_at,
    };
  }
}
