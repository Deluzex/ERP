import { Injectable } from '@nestjs/common';
import { AuditService } from '../../../core/audit/audit.service';
import { DatabasePool } from '../../../core/database/connection';
import { UnitOfWork } from '../../../core/database/unit-of-work';
import { NotFoundError } from '../../../core/errors/not-found.error';
import {
  PaginationQueryDto,
  StockFilterQueryDto,
  StockMovementQueryDto,
} from '../dto/inventory-query.dto';
import {
  CreateStockAdjustmentDto,
  ItemTypeEnum,
} from '../dto/stock-adjustment.dto';
import { TriggerLowStockAlertDto } from '../dto/low-stock-alert.dto';

@Injectable()
export class InventoryService {
  constructor(
    private readonly db: DatabasePool,
    private readonly uow: UnitOfWork,
    private readonly auditService: AuditService,
  ) {}

  // --------------------------------------------------------------------------
  // 6.1 Raw Materials Stock
  // --------------------------------------------------------------------------
  async getRawMaterialsStock(query: StockFilterQueryDto) {
    const page = Math.max(1, query.page || 1);
    const limit = Math.max(1, query.limit || 50);
    const offset = (page - 1) * limit;

    const conditions: string[] = ['rm.is_deleted = false'];
    const params: any[] = [];
    let pIdx = 1;

    if (query.search?.trim()) {
      conditions.push(
        `(rm.name ILIKE $${pIdx} OR rm.item_code ILIKE $${pIdx})`,
      );
      params.push(`%${query.search.trim()}%`);
      pIdx++;
    }

    if (query.categoryId) {
      conditions.push(`rm.category_id = $${pIdx}`);
      params.push(query.categoryId);
      pIdx++;
    }

    if (query.isLowStock === 'true') {
      conditions.push(`rm.current_stock <= rm.minimum_stock`);
    }

    const whereClause = conditions.length
      ? `WHERE ${conditions.join(' AND ')}`
      : '';

    // 1. Summary aggregations
    const summaryRes = await this.db.query<{
      total_items: string;
      total_valuation: string;
      low_stock_count: string;
    }>(
      `SELECT
         COUNT(*)::int as total_items,
         COALESCE(SUM(rm.current_stock * rm.default_purchase_price), 0)::numeric(18,2) as total_valuation,
         COALESCE(SUM(CASE WHEN rm.current_stock <= rm.minimum_stock THEN 1 ELSE 0 END), 0)::int as low_stock_count
       FROM raw_materials rm
       WHERE rm.is_deleted = false`,
    );

    // 2. Count for current query
    const countRes = await this.db.query<{ count: string }>(
      `SELECT COUNT(*)::int as count FROM raw_materials rm ${whereClause}`,
      params,
    );
    const totalCount = parseInt(countRes.rows[0]?.count || '0', 10);

    // 3. Paginated Items
    const itemsRes = await this.db.query<any>(
      `SELECT
         rm.id,
         rm.name,
         rm.item_code,
         rm.category_id,
         c.name as category_name,
         u.symbol as unit,
         rm.opening_stock,
         rm.current_stock,
         rm.minimum_stock,
         rm.reorder_level,
         rm.default_purchase_price,
         rm.gst_percent,
         (rm.current_stock * rm.default_purchase_price)::numeric(18,2) as total_valuation,
         (rm.current_stock <= rm.minimum_stock) as is_low_stock,
         rm.preferred_vendor_ids
       FROM raw_materials rm
       JOIN categories c ON rm.category_id = c.id
       JOIN measurement_units u ON rm.unit_id = u.id
       ${whereClause}
       ORDER BY rm.name ASC
       LIMIT $${pIdx} OFFSET $${pIdx + 1}`,
      [...params, limit, offset],
    );

    return {
      summary: {
        totalItems: Number(summaryRes.rows[0]?.total_items || 0),
        totalValuation: Number(summaryRes.rows[0]?.total_valuation || 0),
        lowStockCount: Number(summaryRes.rows[0]?.low_stock_count || 0),
      },
      items: itemsRes.rows.map((r) => ({
        id: r.id,
        name: r.name,
        itemCode: r.item_code,
        categoryId: r.category_id,
        categoryName: r.category_name,
        unit: r.unit,
        openingStock: Number(r.opening_stock),
        currentStock: Number(r.current_stock),
        minimumStock: Number(r.minimum_stock),
        reorderLevel: Number(r.reorder_level),
        defaultPurchasePrice: Number(r.default_purchase_price),
        gstPercent: Number(r.gst_percent),
        totalValuation: Number(r.total_valuation),
        isLowStock: Boolean(r.is_low_stock),
        preferredVendorIds: r.preferred_vendor_ids || [],
      })),
      pagination: {
        totalItems: totalCount,
        currentPage: page,
        totalPages: Math.ceil(totalCount / limit) || 1,
        limit,
      },
    };
  }

  // --------------------------------------------------------------------------
  // 6.2 Finished Products Stock
  // --------------------------------------------------------------------------
  async getFinishedProductsStock(query: StockFilterQueryDto) {
    const page = Math.max(1, query.page || 1);
    const limit = Math.max(1, query.limit || 50);
    const offset = (page - 1) * limit;

    const conditions: string[] = ['fp.is_deleted = false'];
    const params: any[] = [];
    let pIdx = 1;

    if (query.search?.trim()) {
      conditions.push(
        `(fp.name ILIKE $${pIdx} OR fp.item_code ILIKE $${pIdx})`,
      );
      params.push(`%${query.search.trim()}%`);
      pIdx++;
    }

    if (query.categoryId) {
      conditions.push(`fp.category_id = $${pIdx}`);
      params.push(query.categoryId);
      pIdx++;
    }

    if (query.isLowStock === 'true') {
      conditions.push(`fp.current_stock <= fp.minimum_stock`);
    }

    const whereClause = conditions.length
      ? `WHERE ${conditions.join(' AND ')}`
      : '';

    // Summary aggregations
    const summaryRes = await this.db.query<{
      total_skus: string;
      total_stock_valuation: string;
      total_reserved_stock: string;
      low_stock_count: string;
    }>(
      `SELECT
         COUNT(*)::int as total_skus,
         COALESCE(SUM(fp.current_stock * fp.cost_price), 0)::numeric(18,2) as total_stock_valuation,
         COALESCE(SUM(fp.reserved_stock), 0)::numeric(18,4) as total_reserved_stock,
         COALESCE(SUM(CASE WHEN fp.current_stock <= fp.minimum_stock THEN 1 ELSE 0 END), 0)::int as low_stock_count
       FROM finished_products fp
       WHERE fp.is_deleted = false`,
    );

    const countRes = await this.db.query<{ count: string }>(
      `SELECT COUNT(*)::int as count FROM finished_products fp ${whereClause}`,
      params,
    );
    const totalCount = parseInt(countRes.rows[0]?.count || '0', 10);

    const itemsRes = await this.db.query<any>(
      `SELECT
         fp.id,
         fp.name,
         fp.item_code,
         fp.category_id,
         c.name as category_name,
         u.symbol as unit,
         fp.current_stock,
         fp.reserved_stock,
         (fp.current_stock - fp.reserved_stock)::numeric(18,4) as available_stock,
         fp.purchased_stock,
         fp.produced_stock,
         fp.opening_stock,
         fp.minimum_stock,
         fp.cost_price,
         fp.dealer_selling_price,
         fp.customer_selling_price,
         fp.gst_percent,
         (fp.current_stock * fp.cost_price)::numeric(18,2) as total_valuation,
         (fp.current_stock <= fp.minimum_stock) as is_low_stock
       FROM finished_products fp
       JOIN categories c ON fp.category_id = c.id
       JOIN measurement_units u ON fp.unit_id = u.id
       ${whereClause}
       ORDER BY fp.name ASC
       LIMIT $${pIdx} OFFSET $${pIdx + 1}`,
      [...params, limit, offset],
    );

    return {
      summary: {
        totalSkus: Number(summaryRes.rows[0]?.total_skus || 0),
        totalStockValuation: Number(
          summaryRes.rows[0]?.total_stock_valuation || 0,
        ),
        totalReservedStock: Number(
          summaryRes.rows[0]?.total_reserved_stock || 0,
        ),
        lowStockCount: Number(summaryRes.rows[0]?.low_stock_count || 0),
      },
      items: itemsRes.rows.map((r) => ({
        id: r.id,
        name: r.name,
        itemCode: r.item_code,
        categoryId: r.category_id,
        categoryName: r.category_name,
        unit: r.unit,
        currentStock: Number(r.current_stock),
        reservedStock: Number(r.reserved_stock),
        availableStock: Number(r.available_stock),
        purchasedStock: Number(r.purchased_stock),
        producedStock: Number(r.produced_stock),
        openingStock: Number(r.opening_stock),
        minimumStock: Number(r.minimum_stock),
        costPrice: Number(r.cost_price),
        dealerSellingPrice: Number(r.dealer_selling_price),
        customerSellingPrice: Number(r.customer_selling_price),
        gstPercent: Number(r.gst_percent),
        totalValuation: Number(r.total_valuation),
        isLowStock: Boolean(r.is_low_stock),
      })),
      pagination: {
        totalItems: totalCount,
        currentPage: page,
        totalPages: Math.ceil(totalCount / limit) || 1,
        limit,
      },
    };
  }

  // --------------------------------------------------------------------------
  // 6.3 Immutable Stock Ledger
  // --------------------------------------------------------------------------
  async getStockMovements(query: StockMovementQueryDto) {
    const page = Math.max(1, query.page || 1);
    const limit = Math.max(1, query.limit || 50);
    const offset = (page - 1) * limit;

    const conditions: string[] = ['1=1'];
    const params: any[] = [];
    let pIdx = 1;

    if (query.itemId) {
      conditions.push(`sm.item_id = $${pIdx}`);
      params.push(query.itemId);
      pIdx++;
    }

    if (query.itemType) {
      conditions.push(`sm.item_type = $${pIdx}`);
      params.push(query.itemType);
      pIdx++;
    }

    if (query.transactionType) {
      conditions.push(`sm.transaction_type = $${pIdx}`);
      params.push(query.transactionType);
      pIdx++;
    }

    if (query.startDate) {
      conditions.push(`sm.date >= $${pIdx}`);
      params.push(query.startDate);
      pIdx++;
    }

    if (query.endDate) {
      conditions.push(`sm.date <= $${pIdx}`);
      params.push(query.endDate);
      pIdx++;
    }

    if (query.search?.trim()) {
      conditions.push(
        `(sm.reference_number ILIKE $${pIdx} OR sm.notes ILIKE $${pIdx} OR rm.name ILIKE $${pIdx} OR fp.name ILIKE $${pIdx})`,
      );
      params.push(`%${query.search.trim()}%`);
      pIdx++;
    }

    const whereClause = `WHERE ${conditions.join(' AND ')}`;

    const countRes = await this.db.query<{ count: string }>(
      `SELECT COUNT(*)::int as count
       FROM stock_movements sm
       LEFT JOIN raw_materials rm ON sm.item_id = rm.id AND sm.item_type = 'rawMaterial'
       LEFT JOIN finished_products fp ON sm.item_id = fp.id AND sm.item_type = 'finishedProduct'
       ${whereClause}`,
      params,
    );
    const totalCount = parseInt(countRes.rows[0]?.count || '0', 10);

    const movementsRes = await this.db.query<any>(
      `SELECT
         sm.id,
         sm.date,
         sm.item_id,
         COALESCE(rm.name, fp.name, 'Unknown Item') as item_name,
         COALESCE(rm.item_code, fp.item_code, '') as item_code,
         sm.item_type,
         sm.transaction_type,
         sm.reference_number,
         sm.stock_in,
         sm.stock_out,
         sm.current_balance,
         sm.unit,
         sm.notes,
         COALESCE(u.name, 'System') as performed_by
       FROM stock_movements sm
       LEFT JOIN raw_materials rm ON sm.item_id = rm.id AND sm.item_type = 'rawMaterial'
       LEFT JOIN finished_products fp ON sm.item_id = fp.id AND sm.item_type = 'finishedProduct'
       LEFT JOIN users u ON sm.performed_by = u.id
       ${whereClause}
       ORDER BY sm.date DESC, sm.created_at DESC
       LIMIT $${pIdx} OFFSET $${pIdx + 1}`,
      [...params, limit, offset],
    );

    return {
      items: movementsRes.rows.map((m) => ({
        id: m.id,
        date: m.date,
        itemId: m.item_id,
        itemName: m.item_name,
        itemCode: m.item_code,
        itemType: m.item_type,
        transactionType: m.transaction_type,
        referenceNumber: m.reference_number,
        stockIn: Number(m.stock_in),
        stockOut: Number(m.stock_out),
        currentBalance: Number(m.current_balance),
        unit: m.unit,
        notes: m.notes,
        performedBy: m.performed_by,
      })),
      pagination: {
        totalItems: totalCount,
        currentPage: page,
        totalPages: Math.ceil(totalCount / limit) || 1,
        limit,
      },
    };
  }

  // --------------------------------------------------------------------------
  // 6.4 Perform Stock Adjustment (Transactional & Immutable)
  // --------------------------------------------------------------------------
  async performStockAdjustment(
    dto: CreateStockAdjustmentDto,
    userId: string,
    correlationId?: string,
  ) {
    return this.uow.runInTransaction(async (client) => {
      let item: {
        id: string;
        name: string;
        item_code: string;
        current_stock: string;
        unit: string;
      } | null = null;

      if (dto.itemType === ItemTypeEnum.rawMaterial) {
        const itemRes = await client.query<{
          id: string;
          name: string;
          item_code: string;
          current_stock: string;
          unit: string;
        }>(
          `SELECT rm.id, rm.name, rm.item_code, rm.current_stock, u.symbol as unit
           FROM raw_materials rm
           JOIN measurement_units u ON rm.unit_id = u.id
           WHERE rm.id = $1 AND rm.is_deleted = false
           FOR UPDATE`,
          [dto.itemId],
        );
        item = itemRes.rows[0] || null;
      } else {
        const itemRes = await client.query<{
          id: string;
          name: string;
          item_code: string;
          current_stock: string;
          unit: string;
        }>(
          `SELECT fp.id, fp.name, fp.item_code, fp.current_stock, u.symbol as unit
           FROM finished_products fp
           JOIN measurement_units u ON fp.unit_id = u.id
           WHERE fp.id = $1 AND fp.is_deleted = false
           FOR UPDATE`,
          [dto.itemId],
        );
        item = itemRes.rows[0] || null;
      }

      if (!item) {
        throw new NotFoundError(
          `${dto.itemType === ItemTypeEnum.rawMaterial ? 'Raw material' : 'Finished product'} with ID ${dto.itemId} not found`,
        );
      }

      const currentStockBefore = Number(item.current_stock);
      const adjustedStockAfter = Number(dto.adjustedStockAfter);
      const adjustmentQuantity = adjustedStockAfter - currentStockBefore;

      // Unique sequential/timestamped adjustment number
      const now = new Date();
      const adjustmentNumber = `ADJ-${now.getFullYear()}-${String(Date.now()).slice(-5)}`;

      // 1. Update current_stock in database catalog
      if (dto.itemType === ItemTypeEnum.rawMaterial) {
        await client.query(
          `UPDATE raw_materials SET current_stock = $1, updated_at = now() WHERE id = $2`,
          [adjustedStockAfter, dto.itemId],
        );
      } else {
        await client.query(
          `UPDATE finished_products SET current_stock = $1, updated_at = now() WHERE id = $2`,
          [adjustedStockAfter, dto.itemId],
        );
      }

      // 2. Insert into stock_adjustments record
      const adjRes = await client.query<any>(
        `INSERT INTO stock_adjustments (
           adjustment_number,
           adjustment_date,
           item_id,
           item_type,
           item_name,
           item_code,
           current_stock_before,
           adjusted_stock_after,
           adjustment_quantity,
           unit,
           reason,
           remarks,
           performed_by
         )
         VALUES ($1, now(), $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
         RETURNING *`,
        [
          adjustmentNumber,
          dto.itemId,
          dto.itemType,
          item.name,
          item.item_code,
          currentStockBefore,
          adjustedStockAfter,
          adjustmentQuantity,
          item.unit,
          dto.reason,
          dto.remarks || null,
          userId,
        ],
      );

      // 3. Insert immutable entry into stock_movements ledger
      const stockIn = adjustmentQuantity > 0 ? adjustmentQuantity : 0;
      const stockOut = adjustmentQuantity < 0 ? Math.abs(adjustmentQuantity) : 0;

      await client.query(
        `INSERT INTO stock_movements (
           date,
           item_id,
           item_type,
           transaction_type,
           reference_number,
           stock_in,
           stock_out,
           current_balance,
           unit,
           notes,
           performed_by
         )
         VALUES (now(), $1, $2, 'adjustment', $3, $4, $5, $6, $7, $8, $9)`,
        [
          dto.itemId,
          dto.itemType,
          adjustmentNumber,
          stockIn,
          stockOut,
          adjustedStockAfter,
          item.unit,
          dto.remarks ? `Adjustment (${dto.reason}): ${dto.remarks}` : `Adjustment (${dto.reason})`,
          userId,
        ],
      );

      // Audit log
      await this.auditService.record(
        {
          userId,
          action: 'adjust_stock',
          entityType: 'inventory',
          entityId: dto.itemId,
          beforeSnapshot: { currentStockBefore },
          afterSnapshot: { adjustedStockAfter },
          reason: dto.reason,
          correlationId,
        },
        client,
      );

      const row = adjRes.rows[0];
      return {
        id: row.id,
        adjustmentNumber: row.adjustment_number,
        adjustmentDate: row.adjustment_date,
        itemId: row.item_id,
        itemName: row.item_name,
        itemCode: row.item_code,
        itemType: row.item_type,
        currentStockBefore: Number(row.current_stock_before),
        adjustedStockAfter: Number(row.adjusted_stock_after),
        adjustmentQuantity: Number(row.adjustment_quantity),
        unit: row.unit,
        reason: row.reason,
        remarks: row.remarks,
        performedBy: userId,
        createdAt: row.created_at,
      };
    });
  }

  // --------------------------------------------------------------------------
  // 6.4 List Stock Adjustments
  // --------------------------------------------------------------------------
  async getStockAdjustments(query: PaginationQueryDto) {
    const page = Math.max(1, query.page || 1);
    const limit = Math.max(1, query.limit || 50);
    const offset = (page - 1) * limit;

    const countRes = await this.db.query<{ count: string }>(
      'SELECT COUNT(*)::int as count FROM stock_adjustments',
    );
    const totalCount = parseInt(countRes.rows[0]?.count || '0', 10);

    const res = await this.db.query<any>(
      `SELECT
         sa.id,
         sa.adjustment_number,
         sa.adjustment_date,
         sa.item_id,
         sa.item_type,
         sa.item_name,
         sa.item_code,
         sa.current_stock_before,
         sa.adjusted_stock_after,
         sa.adjustment_quantity,
         sa.unit,
         sa.reason,
         sa.remarks,
         COALESCE(u.name, 'System') as performed_by,
         sa.created_at
       FROM stock_adjustments sa
       LEFT JOIN users u ON sa.performed_by = u.id
       ORDER BY sa.created_at DESC
       LIMIT $1 OFFSET $2`,
      [limit, offset],
    );

    return {
      items: res.rows.map((r) => ({
        id: r.id,
        adjustmentNumber: r.adjustment_number,
        adjustmentDate: r.adjustment_date,
        itemId: r.item_id,
        itemType: r.item_type,
        itemName: r.item_name,
        itemCode: r.item_code,
        currentStockBefore: Number(r.current_stock_before),
        adjustedStockAfter: Number(r.adjusted_stock_after),
        adjustmentQuantity: Number(r.adjustment_quantity),
        unit: r.unit,
        reason: r.reason,
        remarks: r.remarks,
        performedBy: r.performed_by,
        createdAt: r.created_at,
      })),
      pagination: {
        totalItems: totalCount,
        currentPage: page,
        totalPages: Math.ceil(totalCount / limit) || 1,
        limit,
      },
    };
  }

  // --------------------------------------------------------------------------
  // 6.5, 6.6, 6.7 Low Stock Alerts
  // --------------------------------------------------------------------------
  async triggerLowStockAlert(dto: TriggerLowStockAlertDto, userId: string) {
    let item: {
      name: string;
      item_code: string;
      current_stock: string;
      minimum_stock: string;
      reorder_level?: string;
    } | null = null;

    if (dto.itemType === ItemTypeEnum.rawMaterial) {
      const res = await this.db.query<any>(
        'SELECT name, item_code, current_stock, minimum_stock, reorder_level FROM raw_materials WHERE id = $1',
        [dto.itemId],
      );
      item = res.rows[0];
    } else {
      const res = await this.db.query<any>(
        'SELECT name, item_code, current_stock, minimum_stock FROM finished_products WHERE id = $1',
        [dto.itemId],
      );
      item = res.rows[0];
    }

    if (!item) {
      throw new NotFoundError(`Item with ID ${dto.itemId} not found`);
    }

    const currentStock = Number(item.current_stock);
    const minimumStock = Number(item.minimum_stock);
    const reorderLevel = Number(item.reorder_level || minimumStock * 1.5);

    const res = await this.db.query<any>(
      `INSERT INTO low_stock_alerts (
         item_id,
         item_type,
         item_name,
         item_code,
         recipient_id,
         recipient_name,
         recipient_whatsapp,
         custom_message,
         current_stock,
         minimum_stock,
         reorder_level,
         status
       )
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, 'triggered')
       RETURNING *`,
      [
        dto.itemId,
        dto.itemType,
        item.name,
        item.item_code,
        dto.recipientId || null,
        dto.recipientName || null,
        dto.recipientWhatsApp || null,
        dto.customMessage || null,
        currentStock,
        minimumStock,
        reorderLevel,
      ],
    );

    const row = res.rows[0];
    return {
      id: row.id,
      itemId: row.item_id,
      itemType: row.item_type,
      itemName: row.item_name,
      itemCode: row.item_code,
      currentStock: Number(row.current_stock),
      minimumStock: Number(row.minimum_stock),
      reorderLevel: Number(row.reorder_level),
      status: row.status,
      recipientId: row.recipient_id,
      recipientName: row.recipient_name,
      recipientWhatsApp: row.recipient_whatsapp,
      customMessage: row.custom_message,
      createdAt: row.created_at,
    };
  }

  async getLowStockAlerts(query: PaginationQueryDto) {
    const page = Math.max(1, query.page || 1);
    const limit = Math.max(1, query.limit || 50);
    const offset = (page - 1) * limit;

    const countRes = await this.db.query<{ count: string }>(
      'SELECT COUNT(*)::int as count FROM low_stock_alerts',
    );
    const totalCount = parseInt(countRes.rows[0]?.count || '0', 10);

    const res = await this.db.query<any>(
      `SELECT * FROM low_stock_alerts ORDER BY created_at DESC LIMIT $1 OFFSET $2`,
      [limit, offset],
    );

    return {
      items: res.rows.map((r) => ({
        id: r.id,
        itemId: r.item_id,
        itemType: r.item_type,
        itemName: r.item_name,
        itemCode: r.item_code,
        currentStock: Number(r.current_stock),
        minimumStock: Number(r.minimum_stock),
        reorderLevel: Number(r.reorder_level),
        status: r.status,
        recipientId: r.recipient_id,
        recipientName: r.recipient_name,
        recipientWhatsApp: r.recipient_whatsapp,
        customMessage: r.custom_message,
        resolvedAt: r.resolved_at,
        createdAt: r.created_at,
      })),
      pagination: {
        totalItems: totalCount,
        currentPage: page,
        totalPages: Math.ceil(totalCount / limit) || 1,
        limit,
      },
    };
  }

  async resolveLowStockAlert(alertId: string, userId: string) {
    const res = await this.db.query<any>(
      `UPDATE low_stock_alerts
       SET status = 'resolved', resolved_at = now(), resolved_by = $1
       WHERE id = $2
       RETURNING *`,
      [userId || null, alertId],
    );

    if (res.rows.length === 0) {
      throw new NotFoundError(`Low stock alert ${alertId} not found`);
    }

    const row = res.rows[0];
    return {
      id: row.id,
      status: row.status,
      resolvedAt: row.resolved_at,
    };
  }
}
