import { Injectable } from '@nestjs/common';
import { AuditService } from '../../../core/audit/audit.service';
import { Money } from '../../../core/common/money';
import { DatabasePool } from '../../../core/database/connection';
import { ConflictError } from '../../../core/errors/conflict.error';
import { NotFoundError } from '../../../core/errors/not-found.error';
import {
  CreateRawMaterialDto,
  UpdateRawMaterialDto,
} from '../dto/raw-material.dto';

export interface RawMaterialRecord {
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
  reorderLevel: string;
  defaultPurchasePrice: string;
  gstPercent: number;
  preferredVendorIds: string[];
  isLowStock: boolean;
  isDeleted: boolean;
  deletedAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
}

@Injectable()
export class RawMaterialsService {
  constructor(
    private readonly db: DatabasePool,
    private readonly auditService: AuditService,
  ) {}

  async findAll(
    search?: string,
    categoryId?: string,
    lowStockOnly = false,
    includeDeleted = false,
  ): Promise<RawMaterialRecord[]> {
    const conditions: string[] = [];
    const values: unknown[] = [];
    let idx = 1;

    if (!includeDeleted) {
      conditions.push('rm.is_deleted = false');
    }

    if (categoryId) {
      conditions.push(`rm.category_id = $${idx++}`);
      values.push(categoryId);
    }

    if (lowStockOnly) {
      conditions.push('rm.opening_stock <= rm.minimum_stock');
    }

    if (search && search.trim().length > 0) {
      conditions.push(
        `(rm.name ILIKE $${idx} OR rm.item_code ILIKE $${idx} OR c.name ILIKE $${idx})`,
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
      reorder_level: string;
      default_purchase_price: string;
      gst_percent: string;
      preferred_vendor_ids: string[] | null;
      is_deleted: boolean;
      deleted_at: Date | null;
      created_at: Date;
      updated_at: Date;
    }>(
      `SELECT rm.*, c.name AS category_name, u.symbol AS unit_symbol
       FROM raw_materials rm
       JOIN categories c ON c.id = rm.category_id
       JOIN measurement_units u ON u.id = rm.unit_id
       ${whereClause}
       ORDER BY rm.name ASC`,
      values,
    );

    return res.rows.map((r) => this.mapRow(r));
  }

  async findById(id: string): Promise<RawMaterialRecord> {
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
      reorder_level: string;
      default_purchase_price: string;
      gst_percent: string;
      preferred_vendor_ids: string[] | null;
      is_deleted: boolean;
      deleted_at: Date | null;
      created_at: Date;
      updated_at: Date;
    }>(
      `SELECT rm.*, c.name AS category_name, u.symbol AS unit_symbol
       FROM raw_materials rm
       JOIN categories c ON c.id = rm.category_id
       JOIN measurement_units u ON u.id = rm.unit_id
       WHERE rm.id = $1`,
      [id],
    );

    const row = res.rows[0];
    if (!row) {
      throw new NotFoundError('RawMaterial', id);
    }

    return this.mapRow(row);
  }

  async create(
    dto: CreateRawMaterialDto,
    userId?: string,
    correlationId?: string,
  ): Promise<RawMaterialRecord> {
    // Q-06: Partial unique constraint check allowing soft-deleted code reuse
    const existing = await this.db.query(
      'SELECT 1 FROM raw_materials WHERE UPPER(item_code) = UPPER($1) AND is_deleted = false',
      [dto.itemCode.trim()],
    );
    if (existing.rowCount && existing.rowCount > 0) {
      throw new ConflictError(
        `Active raw material with item code "${dto.itemCode}" already exists`,
      );
    }

    const openingStock = Money.formatQuantity(dto.openingStock ?? 0);
    const minimumStock = Money.formatQuantity(dto.minimumStock ?? 0);
    const reorderLevel = Money.formatQuantity(dto.reorderLevel ?? 0);
    const defaultPrice = Money.format(dto.defaultPurchasePrice ?? 0);

    const res = await this.db.query<{ id: string }>(
      `INSERT INTO raw_materials (
        name, item_code, category_id, unit_id, hsn_sac_code,
        opening_stock, minimum_stock, reorder_level, default_purchase_price,
        gst_percent, preferred_vendor_ids
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
        reorderLevel,
        defaultPrice,
        dto.gstPercent ?? 18.0,
        dto.preferredVendorIds || null,
      ],
    );

    const record = await this.findById(res.rows[0].id);

    await this.auditService.log({
      userId,
      userName: 'User',
      action: 'RAW_MATERIAL_CREATE',
      entityType: 'RAW_MATERIAL',
      entityId: record.id,
      afterSnapshot: { ...dto },
      correlationId,
    });

    return record;
  }

  async update(
    id: string,
    dto: UpdateRawMaterialDto,
    userId?: string,
    correlationId?: string,
  ): Promise<RawMaterialRecord> {
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
    if (dto.reorderLevel !== undefined) {
      updates.push(`reorder_level = $${idx++}`);
      values.push(Money.formatQuantity(dto.reorderLevel));
    }
    if (dto.defaultPurchasePrice !== undefined) {
      updates.push(`default_purchase_price = $${idx++}`);
      values.push(Money.format(dto.defaultPurchasePrice));
    }
    if (dto.gstPercent !== undefined) {
      updates.push(`gst_percent = $${idx++}`);
      values.push(dto.gstPercent);
    }
    if (dto.preferredVendorIds !== undefined) {
      updates.push(`preferred_vendor_ids = $${idx++}`);
      values.push(dto.preferredVendorIds);
    }

    if (updates.length > 0) {
      updates.push(`updated_at = NOW()`);
      values.push(id);
      await this.db.query(
        `UPDATE raw_materials SET ${updates.join(', ')} WHERE id = $${idx}`,
        values,
      );
    }

    await this.auditService.log({
      userId,
      userName: 'User',
      action: 'RAW_MATERIAL_UPDATE',
      entityType: 'RAW_MATERIAL',
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

    // Q-06: Soft delete enables immediate item code reuse
    await this.db.query(
      `UPDATE raw_materials
       SET is_deleted = true,
           deleted_at = NOW(),
           updated_at = NOW()
       WHERE id = $1`,
      [id],
    );

    await this.auditService.log({
      userId,
      userName: 'User',
      action: 'RAW_MATERIAL_SOFT_DELETE',
      entityType: 'RAW_MATERIAL',
      entityId: id,
      correlationId,
    });

    return { success: true };
  }

  private mapRow(r: any): RawMaterialRecord {
    const currentStock = parseFloat(r.current_stock ?? r.opening_stock) || 0;
    const minStock = parseFloat(r.minimum_stock) || 0;

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
      reorderLevel: Money.formatQuantity(r.reorder_level),
      defaultPurchasePrice: Money.format(r.default_purchase_price),
      gstPercent: parseFloat(r.gst_percent) || 18.0,
      preferredVendorIds: r.preferred_vendor_ids || [],
      isLowStock: currentStock <= minStock,
      isDeleted: r.is_deleted,
      deletedAt: r.deleted_at,
      createdAt: r.created_at,
      updatedAt: r.updated_at,
    };
  }
}
