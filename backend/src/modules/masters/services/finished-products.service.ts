import { Injectable } from '@nestjs/common';
import { AuditService } from '../../../core/audit/audit.service';
import { Money } from '../../../core/common/money';
import { DatabasePool } from '../../../core/database/connection';
import { UnitOfWork } from '../../../core/database/unit-of-work';
import { ConflictError } from '../../../core/errors/conflict.error';
import { NotFoundError } from '../../../core/errors/not-found.error';
import {
  BulkImportFinishedProductsDto,
  CreateFinishedProductDto,
  UpdateFinishedProductDto,
} from '../dto/finished-product.dto';
import { BulkImportResult } from './raw-materials.service';

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
  transportationCharge: string;
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
    private readonly uow: UnitOfWork,
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
    const transCharge = Money.format(dto.transportationCharge ?? 0);
    const dealerPrice = Money.format(dto.dealerSellingPrice ?? 0);
    const customerPrice = Money.format(dto.customerSellingPrice ?? 0);

    const res = await this.db.query<{ id: string }>(
      `INSERT INTO finished_products (
        name, item_code, category_id, unit_id, hsn_sac_code,
        opening_stock, current_stock, minimum_stock, cost_price, transportation_charge, dealer_selling_price,
        customer_selling_price, gst_percent
      ) VALUES ($1, $2, $3, $4, $5, $6, $6, $7, $8, $9, $10, $11, $12)
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
        transCharge,
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

  async importBulk(
    dto: BulkImportFinishedProductsDto,
    userId?: string,
    correlationId?: string,
  ): Promise<BulkImportResult> {
    const totalRows = dto.items.length;
    const errors: { rowNumber?: number; itemCode?: string; field?: string; message: string }[] = [];
    let duplicateCount = 0;
    let skippedCount = 0;

    // 1. In-payload duplicate check
    const seenCodesInBatch = new Set<string>();
    const uniqueItems: { item: CreateFinishedProductDto; index: number }[] = [];

    for (let i = 0; i < dto.items.length; i++) {
      const item = dto.items[i];
      const code = item.itemCode ? item.itemCode.trim().toUpperCase() : '';
      if (!code) {
        errors.push({
          rowNumber: i + 1,
          field: 'itemCode',
          message: 'Item code is required',
        });
        continue;
      }
      if (seenCodesInBatch.has(code)) {
        duplicateCount++;
        skippedCount++;
        errors.push({
          rowNumber: i + 1,
          itemCode: code,
          field: 'itemCode',
          message: `Duplicate item code "${code}" within upload file`,
        });
        continue;
      }
      seenCodesInBatch.add(code);
      uniqueItems.push({ item, index: i });
    }

    if (uniqueItems.length === 0) {
      return {
        totalRows,
        importedCount: 0,
        duplicateCount,
        skippedCount,
        failedCount: errors.length - duplicateCount,
        importedIds: [],
        errors,
      };
    }

    // 2. Query existing active item codes in DB
    const candidateCodes = uniqueItems.map((u) => u.item.itemCode.trim().toUpperCase());
    const existingRes = await this.db.query<{ item_code: string }>(
      'SELECT UPPER(item_code) AS item_code FROM finished_products WHERE is_deleted = false AND UPPER(item_code) = ANY($1)',
      [candidateCodes],
    );
    const existingCodeSet = new Set(existingRes.rows.map((r) => r.item_code));

    // 3. Query categories and units to ensure references exist
    const catIds = [...new Set(uniqueItems.map((u) => u.item.categoryId))];
    const unitIds = [...new Set(uniqueItems.map((u) => u.item.unitId))];

    const validCatsRes = await this.db.query<{ id: string }>(
      'SELECT id FROM categories WHERE id = ANY($1)',
      [catIds],
    );
    const validCatSet = new Set(validCatsRes.rows.map((r) => r.id));

    const validUnitsRes = await this.db.query<{ id: string }>(
      'SELECT id FROM measurement_units WHERE id = ANY($1)',
      [unitIds],
    );
    const validUnitSet = new Set(validUnitsRes.rows.map((r) => r.id));

    // Filter items to insert
    const itemsToInsert: CreateFinishedProductDto[] = [];
    for (const { item, index } of uniqueItems) {
      const code = item.itemCode.trim().toUpperCase();
      if (existingCodeSet.has(code)) {
        duplicateCount++;
        skippedCount++;
        // Skipped per approved SKIP policy
        continue;
      }

      if (!validCatSet.has(item.categoryId)) {
        errors.push({
          rowNumber: index + 1,
          itemCode: code,
          field: 'categoryId',
          message: `Category with ID "${item.categoryId}" does not exist`,
        });
        continue;
      }

      if (!validUnitSet.has(item.unitId)) {
        errors.push({
          rowNumber: index + 1,
          itemCode: code,
          field: 'unitId',
          message: `Unit with ID "${item.unitId}" does not exist`,
        });
        continue;
      }

      itemsToInsert.push(item);
    }

    if (itemsToInsert.length === 0) {
      return {
        totalRows,
        importedCount: 0,
        duplicateCount,
        skippedCount,
        failedCount: errors.length - duplicateCount,
        importedIds: [],
        errors,
      };
    }

    // 4. Insert in transaction with rollback safety
    const importedIds: string[] = [];
    try {
      await this.uow.runInTransaction(async (tx) => {
        const chunkSize = 100;
        for (let i = 0; i < itemsToInsert.length; i += chunkSize) {
          const chunk = itemsToInsert.slice(i, i + chunkSize);
          const values: unknown[] = [];
          const rowPlaceholders: string[] = [];
          let paramIdx = 1;

          for (const item of chunk) {
            const openingStock = Money.formatQuantity(item.openingStock ?? 0);
            const minimumStock = Money.formatQuantity(item.minimumStock ?? 0);
            const costPrice = Money.format(item.costPrice ?? 0);
            const transCharge = Money.format(item.transportationCharge ?? 0);
            const dealerPrice = Money.format(item.dealerSellingPrice ?? 0);
            const customerPrice = Money.format(item.customerSellingPrice ?? 0);

            const p1 = paramIdx++;
            const p2 = paramIdx++;
            const p3 = paramIdx++;
            const p4 = paramIdx++;
            const p5 = paramIdx++;
            const p6 = paramIdx++;
            const p7 = paramIdx++;
            const p8 = paramIdx++;
            const p9 = paramIdx++;
            const p10 = paramIdx++;
            const p11 = paramIdx++;
            const p12 = paramIdx++;

            values.push(
              item.name.trim(),
              item.itemCode.trim().toUpperCase(),
              item.categoryId,
              item.unitId,
              item.hsnSacCode || null,
              openingStock,
              minimumStock,
              costPrice,
              transCharge,
              dealerPrice,
              customerPrice,
              item.gstPercent ?? 18.0,
            );

            // Notice: opening_stock is $p6, current_stock is also $p6
            rowPlaceholders.push(
              `($${p1}, $${p2}, $${p3}, $${p4}, $${p5}, $${p6}, $${p6}, $${p7}, $${p8}, $${p9}, $${p10}, $${p11}, $${p12})`,
            );
          }

          const insertSql = `
            INSERT INTO finished_products (
              name, item_code, category_id, unit_id, hsn_sac_code,
              opening_stock, current_stock, minimum_stock, cost_price, transportation_charge, dealer_selling_price,
              customer_selling_price, gst_percent
            ) VALUES ${rowPlaceholders.join(', ')}
            RETURNING id
          `;

          const res = await tx.query<{ id: string }>(insertSql, values);
          for (const row of res.rows) {
            importedIds.push(row.id);
          }
        }
      });
    } catch (dbErr: any) {
      return {
        totalRows,
        importedCount: 0,
        duplicateCount,
        skippedCount,
        failedCount: itemsToInsert.length,
        importedIds: [],
        errors: [
          ...errors,
          {
            message: `Database transaction rolled back: ${dbErr.message || 'Concurrent conflict or database error'}`,
          },
        ],
      };
    }

    // 5. Audit Logging
    if (importedIds.length > 0) {
      await this.auditService.log({
        userId,
        userName: 'User',
        action: 'FINISHED_PRODUCT_BULK_IMPORT',
        entityType: 'FINISHED_PRODUCT',
        entityId: importedIds[0],
        afterSnapshot: {
          totalRows,
          importedCount: importedIds.length,
          duplicateCount,
          skippedCount,
        },
        correlationId,
      });
    }

    return {
      totalRows,
      importedCount: importedIds.length,
      duplicateCount,
      skippedCount,
      failedCount: errors.length - duplicateCount,
      importedIds,
      errors,
    };
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
    if (dto.currentStock !== undefined) {
      updates.push(`current_stock = $${idx++}`);
      values.push(Money.formatQuantity(dto.currentStock));
    }
    if (dto.minimumStock !== undefined) {
      updates.push(`minimum_stock = $${idx++}`);
      values.push(Money.formatQuantity(dto.minimumStock));
    }
    if (dto.costPrice !== undefined) {
      updates.push(`cost_price = $${idx++}`);
      values.push(Money.format(dto.costPrice));
    }
    if (dto.transportationCharge !== undefined) {
      updates.push(`transportation_charge = $${idx++}`);
      values.push(Money.format(dto.transportationCharge));
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
    const rawCurrentStock = r.current_stock !== null && r.current_stock !== undefined ? parseFloat(r.current_stock) : null;
    const rawOpeningStock = parseFloat(r.opening_stock) || 0;
    const currentStock = (rawCurrentStock !== null && !isNaN(rawCurrentStock)) ? rawCurrentStock : rawOpeningStock;

    return {
      id: r.id,
      name: r.name,
      itemCode: r.item_code,
      categoryId: r.category_id,
      categoryName: r.category_name,
      unitId: r.unit_id,
      unit: r.unit_symbol,
      hsnSacCode: r.hsn_sac_code,
      currentStock: Money.formatQuantity(currentStock),
      openingStock: Money.formatQuantity(r.opening_stock),
      minimumStock: Money.formatQuantity(r.minimum_stock),
      costPrice: Money.format(r.cost_price),
      transportationCharge: Money.format(r.transportation_charge || 0),
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
