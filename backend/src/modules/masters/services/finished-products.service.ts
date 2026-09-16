import { Injectable } from '@nestjs/common';
import { AuditService } from '../../../core/audit/audit.service';
import { Money } from '../../../core/common/money';
import { DatabasePool } from '../../../core/database/connection';
import { ConflictError } from '../../../core/errors/conflict.error';
import { NotFoundError } from '../../../core/errors/not-found.error';
import {
  CreateFinishedProductDto,
  UpdateFinishedProductDto,
} from '../dto/finished-product.dto';

export interface FinishedProductRecord {
  id: string;
  name: string;
  itemCode: string;
  categoryId: string;
  categoryName: string;
  unitId: string;
  unit: string;
  hsnSacCode: string | null;
  currentStock: string;
  openingStock: string;
  minimumStock: string;
  costPrice: string;
  dealerSellingPrice: string;
  customerSellingPrice: string;
  gstPercent: number;
  isDeleted: boolean;
  deletedAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
}

@Injectable()
export class FinishedProductsService {
  constructor(
    private readonly db: DatabasePool,
    private readonly auditService: AuditService,
  ) {}

  async findAll(
    search?: string,
    categoryId?: string,
    includeDeleted = false,
  ): Promise<FinishedProductRecord[]> {
    const conditions: string[] = [];
    const values: unknown[] = [];
    let idx = 1;

    if (!includeDeleted) {
      conditions.push('fp.is_deleted = false');
    }

    if (categoryId) {
      conditions.push(`fp.category_id = $${idx++}`);
      values.push(categoryId);
    }

    if (search && search.trim().length > 0) {
      conditions.push(
        `(fp.name ILIKE $${idx} OR fp.item_code ILIKE $${idx} OR c.name ILIKE $${idx})`,
      );
      values.push(`%${search.trim()}%`);
      idx++;
    }

    const whereClause = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';

    const res = await this.db.query<{
      id: string;
      name: string;
      item_code: string;
      category_id: string;
      category_name: string;
      unit_id: string;
      unit_symbol: string;
      hsn_sac_code: string | null;
      opening_stock: string;
      minimum_stock: string;
      cost_price: string;
      dealer_selling_price: string;
      customer_selling_price: string;
      gst_percent: string;
      is_deleted: boolean;
      deleted_at: Date | null;
      created_at: Date;
      updated_at: Date;
    }>(
      `SELECT fp.*, c.name AS category_name, u.symbol AS unit_symbol
       FROM finished_products fp
       JOIN categories c ON c.id = fp.category_id
       JOIN measurement_units u ON u.id = fp.unit_id
       ${whereClause}
       ORDER BY fp.name ASC`,
      values,
    );

    return res.rows.map((r) => this.mapRow(r));
  }

  async findById(id: string): Promise<FinishedProductRecord> {
    const res = await this.db.query<{
      id: string;
      name: string;
      item_code: string;
      category_id: string;
      category_name: string;
      unit_id: string;
      unit_symbol: string;
      hsn_sac_code: string | null;
      opening_stock: string;
      minimum_stock: string;
      cost_price: string;
      dealer_selling_price: string;
      customer_selling_price: string;
      gst_percent: string;
      is_deleted: boolean;
      deleted_at: Date | null;
      created_at: Date;
      updated_at: Date;
    }>(
      `SELECT fp.*, c.name AS category_name, u.symbol AS unit_symbol
       FROM finished_products fp
       JOIN categories c ON c.id = fp.category_id
       JOIN measurement_units u ON u.id = fp.unit_id
       WHERE fp.id = $1`,
      [id],
    );

    const row = res.rows[0];
    if (!row) {
      throw new NotFoundError('FinishedProduct', id);
    }

    return this.mapRow(row);
  }

  async create(
    dto: CreateFinishedProductDto,
    userId?: string,
    correlationId?: string,
  ): Promise<FinishedProductRecord> {
    const existing = await this.db.query(
      'SELECT 1 FROM finished_products WHERE UPPER(item_code) = UPPER($1) AND is_deleted = false',
      [dto.itemCode.trim()],
    );
    if (existing.rowCount && existing.rowCount > 0) {
      throw new ConflictError(
        `Active finished product with item code "${dto.itemCode}" already exists`,
      );
    }

    const openingStock = Money.formatQuantity(dto.openingStock ?? 0);
    const minimumStock = Money.formatQuantity(dto.minimumStock ?? 0);
    const costPrice = Money.format(dto.costPrice ?? 0);
    const dealerPrice = Money.format(dto.dealerSellingPrice ?? 0);
    const customerPrice = Money.format(dto.customerSellingPrice ?? 0);

    const res = await this.db.query<{ id: string }>(
      `INSERT INTO finished_products (
        name, item_code, category_id, unit_id, hsn_sac_code,
        opening_stock, minimum_stock, cost_price, dealer_selling_price,
        customer_selling_price, gst_percent
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
      RETURNING id`,
      [
        dto.name.trim(),
        dto.itemCode.trim().toUpperCase(),
        dto.categoryId,
        dto.unitId,
        dto.hsnSacCode || null,
        openingStock,
        minimumStock,
        costPrice,
        dealerPrice,
        customerPrice,
        dto.gstPercent ?? 18.0,
      ],
    );

    const record = await this.findById(res.rows[0].id);

    await this.auditService.log({
      userId,
      userName: 'User',
      action: 'FINISHED_PRODUCT_CREATE',
      entityType: 'FINISHED_PRODUCT',
      entityId: record.id,
      afterSnapshot: { ...dto },
      correlationId,
    });

    return record;
  }

  async update(
    id: string,
    dto: UpdateFinishedProductDto,
    userId?: string,
    correlationId?: string,
  ): Promise<FinishedProductRecord> {
    const existing = await this.findById(id);

    const updates: string[] = [];
    const values: unknown[] = [];
    let idx = 1;

    if (dto.name !== undefined) {
      updates.push(`name = $${idx++}`);
      values.push(dto.name.trim());
    }
    if (dto.categoryId !== undefined) {
      updates.push(`category_id = $${idx++}`);
      values.push(dto.categoryId);
    }
    if (dto.unitId !== undefined) {
      updates.push(`unit_id = $${idx++}`);
      values.push(dto.unitId);
    }
    if (dto.hsnSacCode !== undefined) {
      updates.push(`hsn_sac_code = $${idx++}`);
      values.push(dto.hsnSacCode);
    }
    if (dto.minimumStock !== undefined) {
      updates.push(`minimum_stock = $${idx++}`);
      values.push(Money.formatQuantity(dto.minimumStock));
    }
    if (dto.costPrice !== undefined) {
      updates.push(`cost_price = $${idx++}`);
      values.push(Money.format(dto.costPrice));
    }
    if (dto.dealerSellingPrice !== undefined) {
      updates.push(`dealer_selling_price = $${idx++}`);
      values.push(Money.format(dto.dealerSellingPrice));
    }
    if (dto.customerSellingPrice !== undefined) {
      updates.push(`customer_selling_price = $${idx++}`);
      values.push(Money.format(dto.customerSellingPrice));
    }
    if (dto.gstPercent !== undefined) {
      updates.push(`gst_percent = $${idx++}`);
      values.push(dto.gstPercent);
    }

    if (updates.length > 0) {
      updates.push(`updated_at = NOW()`);
      values.push(id);
      await this.db.query(
        `UPDATE finished_products SET ${updates.join(', ')} WHERE id = $${idx}`,
        values,
      );
    }

    await this.auditService.log({
      userId,
      userName: 'User',
      action: 'FINISHED_PRODUCT_UPDATE',
      entityType: 'FINISHED_PRODUCT',
      entityId: id,
      beforeSnapshot: existing as any,
      afterSnapshot: { ...existing, ...dto },
      correlationId,
    });

    return this.findById(id);
  }

  async delete(
    id: string,
    userId?: string,
    correlationId?: string,
  ): Promise<{ success: boolean }> {
    await this.findById(id);

    await this.db.query(
      `UPDATE finished_products
       SET is_deleted = true,
           deleted_at = NOW(),
           updated_at = NOW()
       WHERE id = $1`,
      [id],
    );

    await this.auditService.log({
      userId,
      userName: 'User',
      action: 'FINISHED_PRODUCT_SOFT_DELETE',
      entityType: 'FINISHED_PRODUCT',
      entityId: id,
      correlationId,
    });

    return { success: true };
  }

  private mapRow(r: any): FinishedProductRecord {
    return {
      id: r.id,
      name: r.name,
      itemCode: r.item_code,
      categoryId: r.category_id,
      categoryName: r.category_name,
      unitId: r.unit_id,
      unit: r.unit_symbol,
      hsnSacCode: r.hsn_sac_code,
      currentStock: Money.formatQuantity(r.current_stock ?? r.opening_stock),
      openingStock: Money.formatQuantity(r.opening_stock),
      minimumStock: Money.formatQuantity(r.minimum_stock),
      costPrice: Money.format(r.cost_price),
      dealerSellingPrice: Money.format(r.dealer_selling_price),
      customerSellingPrice: Money.format(r.customer_selling_price),
      gstPercent: parseFloat(r.gst_percent) || 18.0,
      isDeleted: r.is_deleted,
      deletedAt: r.deleted_at,
      createdAt: r.created_at,
      updatedAt: r.updated_at,
    };
  }
}
