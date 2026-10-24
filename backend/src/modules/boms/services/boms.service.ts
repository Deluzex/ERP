import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { DatabasePool } from '../../../core/database/connection';
import { TransactionalContext, UnitOfWork } from '../../../core/database/unit-of-work';
import {
  BomQueryDto,
  BomStatusEnum,
  CreateBomDto,
  UpdateBomDto,
} from '../dto/bom.dto';

@Injectable()
export class BomsService {
  constructor(
    private readonly db: DatabasePool,
    private readonly uow: UnitOfWork,
  ) {}

  // --------------------------------------------------------------------------
  // 3.2 List BOMs (with Pagination & Filter)
  // --------------------------------------------------------------------------
  async findAll(query: BomQueryDto) {
    const page = query.page || 1;
    const limit = query.limit || 25;
    const offset = (page - 1) * limit;

    const conditions: string[] = [];
    const values: any[] = [];
    let idx = 1;

    if (query.productId) {
      conditions.push(`b.finished_product_id = $${idx++}`);
      values.push(query.productId);
    }

    if (query.status) {
      conditions.push(`b.status = $${idx++}`);
      values.push(query.status);
    }

    if (query.search && query.search.trim().length > 0) {
      conditions.push(
        `(b.bom_number ILIKE $${idx} OR fp.name ILIKE $${idx} OR fp.item_code ILIKE $${idx})`,
      );
      values.push(`%${query.search.trim()}%`);
      idx++;
    }

    const whereClause = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';

    const countRes = await this.db.query<{ count: string }>(
      `SELECT count(*) 
       FROM boms b
       JOIN finished_products fp ON b.finished_product_id = fp.id
       ${whereClause}`,
      values,
    );
    const totalItems = parseInt(countRes.rows[0]?.count || '0', 10);
    const totalPages = Math.ceil(totalItems / limit) || 1;

    values.push(limit);
    values.push(offset);

    const rowsRes = await this.db.query<any>(
      `SELECT b.*, 
              fp.name as finished_product_name, 
              fp.item_code as finished_product_code,
              u.symbol as unit,
              (SELECT count(*) FROM bom_items bi WHERE bi.bom_id = b.id) as item_count
       FROM boms b
       JOIN finished_products fp ON b.finished_product_id = fp.id
       LEFT JOIN measurement_units u ON fp.unit_id = u.id
       ${whereClause}
       ORDER BY b.created_at DESC
       LIMIT $${idx++} OFFSET $${idx++}`,
      values,
    );

    return {
      items: rowsRes.rows.map((r) => ({
        id: r.id,
        bomNumber: r.bom_number,
        finishedProductId: r.finished_product_id,
        finishedProductName: r.finished_product_name,
        finishedProductCode: r.finished_product_code,
        version: r.version,
        status: r.status,
        yieldQuantity: parseFloat(r.yield_quantity),
        unit: r.unit || 'PCS',
        itemCount: parseInt(r.item_count, 10),
        totalCost: parseFloat(r.total_cost),
        notes: r.notes,
        createdAt: r.created_at,
        updatedAt: r.updated_at,
      })),
      pagination: {
        totalItems,
        totalPages,
        currentPage: page,
        limit,
        hasNextPage: page < totalPages,
        hasPrevPage: page > 1,
      },
    };
  }

  // --------------------------------------------------------------------------
  // 3.4 Get BOM Details by ID
  // --------------------------------------------------------------------------
  async findById(id: string, tx?: TransactionalContext) {
    const runQuery = <T extends import('pg').QueryResultRow>(sql: string, params?: any[]) =>
      tx ? tx.query<T>(sql, params) : this.db.query<T>(sql, params);

    const bomRes = await runQuery<any>(
      `SELECT b.*, 
              fp.name as finished_product_name, 
              fp.item_code as finished_product_code,
              u.symbol as unit
       FROM boms b
       JOIN finished_products fp ON b.finished_product_id = fp.id
       LEFT JOIN measurement_units u ON fp.unit_id = u.id
       WHERE b.id = $1`,
      [id],
    );

    if (bomRes.rows.length === 0) {
      throw new NotFoundException(`BOM with ID ${id} not found`);
    }

    const bom = bomRes.rows[0];

    const itemsRes = await runQuery<any>(
      `SELECT bi.*, 
              rm.name as raw_material_name, 
              rm.item_code as raw_material_code,
              rm.default_purchase_price as current_purchase_price
       FROM bom_items bi
       JOIN raw_materials rm ON bi.raw_material_id = rm.id
       WHERE bi.bom_id = $1
       ORDER BY bi.created_at ASC`,
      [id],
    );

    const items = itemsRes.rows.map((i) => {
      const qty = parseFloat(i.quantity);
      const scrap = parseFloat(i.scrap_percentage || '0');
      const unitCost = parseFloat(i.unit_cost);
      const effectiveQty = qty * (1 + scrap / 100);
      const lineTotalCost = Math.round(effectiveQty * unitCost * 100) / 100;

      return {
        id: i.id,
        rawMaterialId: i.raw_material_id,
        rawMaterialName: i.raw_material_name,
        rawMaterialCode: i.raw_material_code,
        quantity: qty,
        unit: i.unit,
        unitCost,
        scrapPercentage: scrap,
        lineTotalCost,
        itemNotes: i.item_notes,
      };
    });

    return {
      id: bom.id,
      bomNumber: bom.bom_number,
      finishedProductId: bom.finished_product_id,
      finishedProductName: bom.finished_product_name,
      finishedProductCode: bom.finished_product_code,
      version: bom.version,
      status: bom.status,
      yieldQuantity: parseFloat(bom.yield_quantity),
      unit: bom.unit || 'PCS',
      totalCost: parseFloat(bom.total_cost),
      notes: bom.notes,
      createdAt: bom.created_at,
      updatedAt: bom.updated_at,
      items,
    };
  }

  // --------------------------------------------------------------------------
  // 3.3 Create New BOM
  // --------------------------------------------------------------------------
  async create(dto: CreateBomDto, userId?: string) {
    return this.uow.runInTransaction(async (client) => {
      // 1. Verify finished product exists
      const fpRes = await client.query<any>(
        `SELECT fp.*, u.symbol as unit_symbol 
         FROM finished_products fp
         LEFT JOIN measurement_units u ON fp.unit_id = u.id
         WHERE fp.id = $1`,
        [dto.finishedProductId],
      );
      if (fpRes.rows.length === 0) {
        throw new NotFoundException(`Finished product with ID ${dto.finishedProductId} not found`);
      }
      const finishedProduct = fpRes.rows[0];

      // 2. Determine version: max + 1
      const versionRes = await client.query<{ max_version: number }>(
        `SELECT COALESCE(MAX(version), 0) as max_version 
         FROM boms 
         WHERE finished_product_id = $1`,
        [dto.finishedProductId],
      );
      const nextVersion = (versionRes.rows[0]?.max_version || 0) + 1;

      // 3. Generate BOM number
      const bomNumber = `BOM-${finishedProduct.item_code}-V${nextVersion}`;

      // 4. Calculate items cost & verify raw materials
      let calculatedTotalCost = 0;
      const resolvedItems: any[] = [];

      for (const item of dto.items) {
        const rmRes = await client.query<any>(
          `SELECT rm.*, u.symbol as unit_symbol 
           FROM raw_materials rm
           LEFT JOIN measurement_units u ON rm.unit_id = u.id
           WHERE rm.id = $1`,
          [item.rawMaterialId],
        );
        if (rmRes.rows.length === 0) {
          throw new BadRequestException(`Raw material with ID ${item.rawMaterialId} not found`);
        }
        const rawMaterial = rmRes.rows[0];
        const unitCost = parseFloat(rawMaterial.default_purchase_price || '0');
        const scrap = item.scrapPercentage || 0;
        const effectiveQty = item.quantity * (1 + scrap / 100);
        const lineCost = effectiveQty * unitCost;
        calculatedTotalCost += lineCost;

        resolvedItems.push({
          rawMaterialId: item.rawMaterialId,
          rawMaterialName: rawMaterial.name,
          rawMaterialCode: rawMaterial.item_code,
          quantity: item.quantity,
          unit: item.unit || rawMaterial.unit_symbol || 'PCS',
          unitCost,
          scrapPercentage: scrap,
          itemNotes: item.itemNotes || null,
        });
      }

      calculatedTotalCost = Math.round(calculatedTotalCost * 100) / 100;
      const status = dto.status || BomStatusEnum.DRAFT;

      // If status is ACTIVE, mark previous ACTIVE as OBSOLETE
      if (status === BomStatusEnum.ACTIVE) {
        await client.query(
          `UPDATE boms SET status = 'OBSOLETE', updated_at = NOW() 
           WHERE finished_product_id = $1 AND status = 'ACTIVE'`,
          [dto.finishedProductId],
        );

        // Sync finished product cost price
        await client.query(
          `UPDATE finished_products SET cost_price = $1, updated_at = NOW() WHERE id = $2`,
          [calculatedTotalCost, dto.finishedProductId],
        );
      }

      // 5. Insert BOM header
      const bomInsert = await client.query<any>(
        `INSERT INTO boms (
           bom_number, finished_product_id, version, status,
           yield_quantity, total_cost, notes
         ) VALUES ($1, $2, $3, $4, $5, $6, $7)
         RETURNING *`,
        [
          bomNumber,
          dto.finishedProductId,
          nextVersion,
          status,
          dto.yieldQuantity || 1.0,
          calculatedTotalCost,
          dto.notes || null,
        ],
      );
      const createdBom = bomInsert.rows[0];

      // 6. Insert BOM items
      for (const item of resolvedItems) {
        await client.query(
          `INSERT INTO bom_items (
             bom_id, raw_material_id, raw_material_name, raw_material_code,
             quantity, quantity_per_unit, unit, unit_cost, scrap_percentage, item_notes
           ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
          [
            createdBom.id,
            item.rawMaterialId,
            item.rawMaterialName,
            item.rawMaterialCode,
            item.quantity,
            item.quantity,
            item.unit,
            item.unitCost,
            item.scrapPercentage,
            item.itemNotes,
          ],
        );
      }

      return {
        id: createdBom.id,
        bomNumber: createdBom.bom_number,
        finishedProductId: createdBom.finished_product_id,
        version: createdBom.version,
        status: createdBom.status,
        yieldQuantity: parseFloat(createdBom.yield_quantity),
        totalCost: parseFloat(createdBom.total_cost),
        itemCount: resolvedItems.length,
        createdAt: createdBom.created_at,
      };
    });
  }

  // --------------------------------------------------------------------------
  // 3.5 Update BOM (Only if DRAFT)
  // --------------------------------------------------------------------------
  async update(id: string, dto: UpdateBomDto, userId?: string) {
    return this.uow.runInTransaction(async (client) => {
      const existingRes = await client.query<any>(
        `SELECT * FROM boms WHERE id = $1`,
        [id],
      );
      if (existingRes.rows.length === 0) {
        throw new NotFoundException(`BOM with ID ${id} not found`);
      }
      const existing = existingRes.rows[0];

      if (existing.status !== BomStatusEnum.DRAFT) {
        throw new BadRequestException(
          'Active or obsolete BOM cannot be modified directly. Clone to a new version instead.',
        );
      }

      let totalCost = parseFloat(existing.total_cost);

      if (dto.items && dto.items.length > 0) {
        // Delete old items and insert new items
        await client.query(`DELETE FROM bom_items WHERE bom_id = $1`, [id]);

        let calculatedTotalCost = 0;
        for (const item of dto.items) {
          const rmRes = await client.query<any>(
            `SELECT rm.*, u.symbol as unit_symbol 
             FROM raw_materials rm
             LEFT JOIN measurement_units u ON rm.unit_id = u.id
             WHERE rm.id = $1`,
            [item.rawMaterialId],
          );
          if (rmRes.rows.length === 0) {
            throw new BadRequestException(`Raw material with ID ${item.rawMaterialId} not found`);
          }
          const rawMaterial = rmRes.rows[0];
          const unitCost = parseFloat(rawMaterial.default_purchase_price || '0');
          const scrap = item.scrapPercentage || 0;
          const effectiveQty = item.quantity * (1 + scrap / 100);
          const lineCost = effectiveQty * unitCost;
          calculatedTotalCost += lineCost;

          await client.query(
            `INSERT INTO bom_items (
               bom_id, raw_material_id, raw_material_name, raw_material_code,
               quantity, quantity_per_unit, unit, unit_cost, scrap_percentage, item_notes
             ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
            [
              id,
              item.rawMaterialId,
              rawMaterial.name,
              rawMaterial.item_code,
              item.quantity,
              item.quantity,
              item.unit || rawMaterial.unit_symbol || 'PCS',
              unitCost,
              scrap,
              item.itemNotes || null,
            ],
          );
        }
        totalCost = Math.round(calculatedTotalCost * 100) / 100;
      }

      await client.query(
        `UPDATE boms SET 
           yield_quantity = COALESCE($1, yield_quantity),
           notes = COALESCE($2, notes),
           total_cost = $3,
           updated_at = NOW()
         WHERE id = $4`,
        [dto.yieldQuantity || null, dto.notes || null, totalCost, id],
      );

      return this.findById(id, client);
    });
  }

  // --------------------------------------------------------------------------
  // 3.6 Duplicate / Clone BOM Version
  // --------------------------------------------------------------------------
  async duplicate(id: string, userId?: string) {
    const parent = await this.findById(id);

    return this.uow.runInTransaction(async (client) => {
      // Find max version for this product
      const maxVerRes = await client.query<{ max_version: number }>(
        `SELECT COALESCE(MAX(version), 0) as max_version 
         FROM boms 
         WHERE finished_product_id = $1`,
        [parent.finishedProductId],
      );
      const newVersion = (maxVerRes.rows[0]?.max_version || parent.version) + 1;
      const newBomNumber = `BOM-${parent.finishedProductCode}-V${newVersion}`;

      const insertRes = await client.query<any>(
        `INSERT INTO boms (
           bom_number, finished_product_id, version, status,
           yield_quantity, total_cost, notes
         ) VALUES ($1, $2, $3, 'DRAFT', $4, $5, $6)
         RETURNING *`,
        [
          newBomNumber,
          parent.finishedProductId,
          newVersion,
          parent.yieldQuantity,
          parent.totalCost,
          `Cloned from ${parent.bomNumber}`,
        ],
      );
      const newBom = insertRes.rows[0];

      // Clone child items
      for (const item of parent.items) {
        await client.query(
          `INSERT INTO bom_items (
             bom_id, raw_material_id, raw_material_name, raw_material_code,
             quantity, quantity_per_unit, unit, unit_cost, scrap_percentage, item_notes
           ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
          [
            newBom.id,
            item.rawMaterialId,
            item.rawMaterialName,
            item.rawMaterialCode,
            item.quantity,
            item.quantity,
            item.unit,
            item.unitCost,
            item.scrapPercentage,
            item.itemNotes,
          ],
        );
      }

      return {
        newBomId: newBom.id,
        bomNumber: newBom.bom_number,
        version: newBom.version,
        status: newBom.status,
        parentBomId: id,
      };
    });
  }

  // --------------------------------------------------------------------------
  // 3.7 Update BOM Lifecycle Status
  // --------------------------------------------------------------------------
  async updateStatus(id: string, status: BomStatusEnum, userId?: string) {
    return this.uow.runInTransaction(async (client) => {
      const bomRes = await client.query<any>(
        `SELECT * FROM boms WHERE id = $1`,
        [id],
      );
      if (bomRes.rows.length === 0) {
        throw new NotFoundException(`BOM with ID ${id} not found`);
      }
      const bom = bomRes.rows[0];

      if (status === BomStatusEnum.ACTIVE) {
        // Mark any existing active BOM for product as obsolete
        await client.query(
          `UPDATE boms SET status = 'OBSOLETE', updated_at = NOW() 
           WHERE finished_product_id = $1 AND id != $2 AND status = 'ACTIVE'`,
          [bom.finished_product_id, id],
        );

        // Sync finished product cost price
        await client.query(
          `UPDATE finished_products SET cost_price = $1, updated_at = NOW() WHERE id = $2`,
          [bom.total_cost, bom.finished_product_id],
        );
      }

      await client.query(
        `UPDATE boms SET status = $1, updated_at = NOW() WHERE id = $2`,
        [status, id],
      );

      return this.findById(id, client);
    });
  }

  // --------------------------------------------------------------------------
  // 3.8 Dynamic Cost Rollup API
  // --------------------------------------------------------------------------
  async getCostRollup(id: string) {
    const bom = await this.findById(id);

    // Fetch finished product customer selling price
    const fpRes = await this.db.query<any>(
      `SELECT customer_selling_price FROM finished_products WHERE id = $1`,
      [bom.finishedProductId],
    );
    const sellingPrice = parseFloat(fpRes.rows[0]?.customer_selling_price || '0');

    let currentMarketCost = 0;
    const costBreakdown: any[] = [];

    for (const item of bom.items) {
      const rmRes = await this.db.query<any>(
        `SELECT default_purchase_price FROM raw_materials WHERE id = $1`,
        [item.rawMaterialId],
      );
      const latestPurchaseRate = parseFloat(rmRes.rows[0]?.default_purchase_price || '0');
      const effectiveQty = item.quantity * (1 + item.scrapPercentage / 100);
      const currentLineCost = effectiveQty * latestPurchaseRate;
      currentMarketCost += currentLineCost;

      costBreakdown.push({
        rawMaterialId: item.rawMaterialId,
        rawMaterialName: item.rawMaterialName,
        bomUnitCost: item.unitCost,
        latestPurchaseRate,
        lineDifference: Math.round((currentLineCost - item.lineTotalCost) * 100) / 100,
      });
    }

    currentMarketCost = Math.round(currentMarketCost * 100) / 100;
    const storedBomCost = bom.totalCost;
    const costVariance = Math.round((currentMarketCost - storedBomCost) * 100) / 100;
    const costVariancePercent = storedBomCost > 0
      ? Math.round((costVariance / storedBomCost) * 10000) / 100
      : 0;

    let currentGrossMarginPercent = 0;
    if (sellingPrice > 0) {
      const margin = sellingPrice - currentMarketCost;
      currentGrossMarginPercent = Math.round((margin / sellingPrice) * 10000) / 100;
    }

    return {
      bomId: id,
      storedBomCost,
      currentMarketCost,
      costVariance,
      costVariancePercent,
      sellingPriceCustomer: sellingPrice,
      currentGrossMarginPercent,
      costBreakdown,
    };
  }

  // --------------------------------------------------------------------------
  // 3.9 Get Active BOM by Finished Product ID
  // --------------------------------------------------------------------------
  async getActiveBomByProduct(productId: string) {
    const res = await this.db.query<any>(
      `SELECT id FROM boms WHERE finished_product_id = $1 AND status = 'ACTIVE' ORDER BY created_at DESC LIMIT 1`,
      [productId],
    );

    if (res.rows.length === 0) {
      return null;
    }

    return this.findById(res.rows[0].id);
  }
}
